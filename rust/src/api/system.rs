pub fn open_by_browser(url: String) -> anyhow::Result<()> {
    opener::open_browser(url)?;
    Ok(())
}