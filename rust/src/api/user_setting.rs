use alipan::GrantType;
use serde_json::json;
use std::collections::HashMap;
use std::convert::Infallible;
use lazy_static::lazy_static;
use warp::http::Response;
use warp::hyper::Body;
use warp::{Filter, Reply};
use tokio::sync::oneshot;
use tokio::sync::Mutex;
use tokio::sync::oneshot::Sender;
use crate::data_obj::AppConfig;
use crate::database::properties::property::save_property;

lazy_static! {
    static ref SHUTDOWN: Mutex<Option<Sender<()>>> = Mutex::new(None);
}

pub async fn start_login_service() -> anyhow::Result<()> {
    let _jh = tokio::spawn(run_warp_server(23767)).await?;
    Ok(())
}

pub async fn stop_login_service() -> anyhow::Result<()> {
    let mut _lock = SHUTDOWN.lock().await;
    if let Some(s) = _lock.take() {
        s.send(()).ok();
    }
    *_lock = None;
    Ok(())
}

async fn run_warp_server(port: u16) -> anyhow::Result<()> {
    let (s, r) = oneshot::channel::<()>();
    let mut _lock = SHUTDOWN.lock().await;
    *_lock = Some(s);
    drop(_lock);
    let routes = index().or(api());
    let (_, server) = warp::serve(routes).bind_with_graceful_shutdown(
        ([127, 0, 0, 1], port),
        async {
            r.await.ok();
        },
    );
    let _jh = tokio::spawn(server);
    Ok(())
}

fn index() -> impl Filter<Extract=impl Reply, Error=warp::Rejection> + Clone {
    let mut static_resource_map = HashMap::<&str, &str>::new();
    static_resource_map.insert("index.html", include_str!("../../html/index.html"));
    let static_resource_map = static_resource_map;
    warp::path!("html" / String)
        .and(warp::get())
        .map(move |file_name: String| {
            if let Some(resource) = static_resource_map.get(file_name.as_str()) {
                let mime = match file_name.split('.').last() {
                    Some("html") => "text/html",
                    Some("css") => "text/css",
                    Some("js") => "application/javascript",
                    _ => "text/plain",
                };
                warp::reply::with_header(warp::reply::html(*resource), "Content-Type", mime)
                    .into_response()
            } else {
                warp::reply::with_status(
                    warp::reply::html("Not Found"),
                    warp::http::StatusCode::NOT_FOUND,
                )
                    .into_response()
            }
        })
}

fn api() -> impl Filter<Extract=impl warp::Reply, Error=warp::Rejection> + Clone {
    url_by_app_config()
        .or(oauth_authorize())
}

fn url_by_app_config() -> impl Filter<Extract=impl warp::Reply, Error=warp::Rejection> + Clone {
    warp::path!("api" / "url_by_app_config")
        .and(warp::post())
        .and(warp::body::json())
        .and_then(url_by_app_config_body)
}

async fn url_by_app_config_body(
    app_config: AppConfig,
) -> Result<impl warp::Reply, Infallible> {
    map_err(url_by_app_config_inner(app_config).await)
}

// todo: lazy_static random password
static PASSWORD: &'static str = "!@#$$%^WIUIYuj6";

async fn url_by_app_config_inner(
    app_config: AppConfig,
) -> anyhow::Result<Response<Body>> {
    let oauth_client = alipan::OAuthClient::default()
        .set_client_id(app_config.client_id.as_str())
        .await
        .set_client_secret(app_config.client_secret.as_str())
        .await;

    let state = toml::to_string(&app_config).map_err(|e| anyhow::anyhow!("序列化配置时出错: {}", e))?;
    let state = crate::custom_crypto::encrypt_buff_to_base64(
        state.as_bytes(),
        PASSWORD.as_bytes(),
    ).map_err(|e| anyhow::anyhow!("加密配置时出错: {}", e))?;

    let url = oauth_client
        .oauth_authorize()
        .await
        .redirect_uri("http://localhost:23767/oauth_authorize")
        .scope("user:base,file:all:read,file:all:write,album:shared:read")
        .state(state)
        .build()?;

    Ok(warp::reply::json(&json!({
        "url": url,
    }))
        .into_response())
}

fn oauth_authorize() -> impl Filter<Extract=impl warp::Reply, Error=warp::Rejection> + Clone {
    warp::path!("oauth_authorize")
        .and(warp::get())
        .and(warp::query::<HashMap<String, String>>())
        .and_then(oauth_authorize_body)
}

async fn oauth_authorize_body(
    query: HashMap<String, String>,
) -> Result<impl warp::Reply, Infallible> {
    map_err(oauth_authorize_body_inner(query).await)
}

async fn oauth_authorize_body_inner(
    query: HashMap<String, String>,
) -> anyhow::Result<Response<Body>> {
    let code = query
        .get("code")
        .ok_or_else(|| anyhow::anyhow!("code 未找到"))?;

    let state = query
        .get("state")
        .ok_or_else(|| anyhow::anyhow!("state 未找到"))?;

    let state = crate::custom_crypto::decrypt_base64(
        state,
        PASSWORD.as_bytes(),
    ).map_err(|e| anyhow::anyhow!("解密配置时出错: {}", e))?;

    let app_config: AppConfig = toml::from_str(&String::from_utf8(state)?)
        .map_err(|e| anyhow::anyhow!("反序列化配置时出错: {}", e))?;

    let oauth_client = alipan::OAuthClient::default()
        .set_client_id(app_config.client_id.as_str())
        .await
        .set_client_secret(app_config.client_secret.as_str())
        .await;

    let raw_token = oauth_client
        .oauth_access_token()
        .await
        .grant_type(GrantType::AuthorizationCode)
        .code(code.as_str())
        .request()
        .await?;

    let access_token = alipan::AccessToken::wrap_oauth_token(raw_token);

    let config: crate::data_obj::Config = crate::data_obj::Config {
        app: app_config,
        access_token: access_token.clone(),
    };

    save_property("account_config".to_owned(), serde_json::to_string(&config)?).await?;

    Ok(warp::reply::html(include_str!("../../html/success.html")).into_response())
}

fn map_err(result: anyhow::Result<Response<Body>>) -> Result<impl warp::Reply, Infallible> {
    match result {
        Ok(reply) => Ok(reply),
        Err(err) => Ok(warp::reply::with_status(
            warp::reply::html(format!("Error: {}", err)),
            warp::http::StatusCode::INTERNAL_SERVER_ERROR,
        )
            .into_response()),
    }
}


