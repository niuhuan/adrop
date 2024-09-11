pub fn open_by_browser(url: String) -> anyhow::Result<()> {
    opener::open_browser(url)?;
    Ok(())
}

pub fn open_file(path: String) -> anyhow::Result<()> {
    opener::open(path)?;
    Ok(())
}

pub async fn show_file_in_explorer(path: String) -> anyhow::Result<()> {
    #[cfg(target_os = "macos")]
    {
        tokio::process::Command::new("open")
            .arg("-R")
            .arg(path)
            .status()
            .await?;
    }
    #[cfg(target_os = "windows")]
    {
        tokio::process::Command::new("explorer")
            .arg(format!("/select,\"{path}\""))
            .status()
            .await?;
    }
    #[cfg(target_os = "linux")]
    {
        tokio::process::Command::new("xdg-open")
            .arg(format("--select={path}"))
            .status()
            .await?;
    }
    Ok(())
}