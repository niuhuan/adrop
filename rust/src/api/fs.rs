use flutter_rust_bridge::for_generated::anyhow;
use crate::utils::join_paths;

pub fn desktop_root() -> anyhow::Result<String> {
    #[cfg(target_os = "windows")]
    {
        use anyhow::Context;
        let data = std::env::var("APPDATA")?.to_string();
        Ok(join_paths(vec![
            data.as_str(),
            "opensource",
            "adrop",
        ]))
    }
    #[cfg(target_os = "macos")]
    {
        use anyhow::Context;
        let home = std::env::var_os("HOME")
            .with_context(|| "error")?
            .to_str()
            .with_context(|| "error")?
            .to_string();
        Ok(join_paths(vec![
            home.as_str(),
            "Library",
            "Application Support",
            "opensource",
            "adrop",
        ]))
    }
    #[cfg(target_os = "linux")]
    {
        use anyhow::Context;
        let home = std::env::var_os("HOME")
            .with_context(|| "error")?
            .to_str()
            .with_context(|| "error")?
            .to_string();
        Ok(join_paths(vec![home.as_str(), ".opensource", "adrop"]))
    }
    #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
    panic!("未支持的平台")
}
