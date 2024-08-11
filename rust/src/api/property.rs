pub async fn get_property(
    key: String,
) -> anyhow::Result<String> {
    crate::database::properties::property::load_property(key.as_str()).await
}

pub async fn set_property(
    key: String,
    value: String,
) -> anyhow::Result<()> {
    crate::database::properties::property::save_property(key, value).await
}