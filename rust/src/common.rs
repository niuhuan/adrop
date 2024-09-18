use std::sync::Arc;
use reqwest::Body;
use tokio::sync::mpsc::Sender;

pub struct PutResource {
    pub agent: Arc<reqwest::Client>,
    pub url: String,
    pub resource: Body,
}

impl PutResource {
    #[allow(dead_code)]
    pub async fn put(self) -> anyhow::Result<()> {
        let _text = self
            .agent
            .request(reqwest::Method::PUT, self.url.as_str())
            .body(self.resource)
            .send()
            .await?
            .error_for_status()?
            .text()
            .await?;
        Ok(())
    }
}

impl PutResource {
    #[allow(dead_code)]
    pub async fn file_resource(path: &str) -> anyhow::Result<Body> {
        let file = tokio::fs::read(path).await?;
        Ok(Body::from(file))
    }

    pub fn channel_resource() -> (Sender<anyhow::Result<Vec<u8>>>, Body) {
        let (sender, receiver) = tokio::sync::mpsc::channel::<anyhow::Result<Vec<u8>>>(16);
        let body = Body::wrap_stream(tokio_stream::wrappers::ReceiverStream::new(receiver));
        (sender, body)
    }

    #[allow(dead_code)]
    pub fn bytes_body(bytes: Vec<u8>) -> Body {
        Body::from(bytes)
    }
}
