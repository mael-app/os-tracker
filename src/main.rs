use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::{env, fs, process, thread, time::Duration};

#[derive(Deserialize)]
struct Config {
    api_url: String,
    token: String,
    #[serde(default = "default_interval")]
    interval_secs: u64,
}

fn default_interval() -> u64 {
    120
}

#[derive(Serialize)]
struct Heartbeat<'a> {
    os: &'a str,
}

fn load_config() -> Config {
    if let (Ok(api_url), Ok(token)) = (
        env::var("OS_TRACKER_API_URL"),
        env::var("OS_TRACKER_TOKEN"),
    ) {
        let interval_secs = env::var("OS_TRACKER_INTERVAL")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or_else(default_interval);

        return Config {
            api_url,
            token,
            interval_secs,
        };
    }

    let project_dirs = ProjectDirs::from("", "", "os-tracker")
        .expect("Failed to determine user configuration directory");
    let config_path = project_dirs.config_dir().join("config.toml");

    let content = fs::read_to_string(&config_path).unwrap_or_else(|err| {
        eprintln!("Failed to read config file {}: {}", config_path.display(), err);
        eprintln!("Create the config file or set OS_TRACKER_API_URL and OS_TRACKER_TOKEN environment variables.");
        process::exit(1);
    });

    toml::from_str(&content).unwrap_or_else(|err| {
        eprintln!("Failed to parse config file: {err}");
        process::exit(1);
    })
}

fn send_heartbeat(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    let os = env::consts::OS;
    let payload = Heartbeat { os };

    let url = format!("{}/heartbeat", config.api_url.trim_end_matches('/'));
    let response = ureq::post(&url)
        .header("Authorization", &format!("Bearer {}", config.token))
        .header("Content-Type", "application/json")
        .send_json(&payload)?;

    log::info!("Heartbeat sent: os={}, status={}", os, response.status());
    Ok(())
}

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let args: Vec<String> = env::args().collect();
    if args.len() > 1 && (args[1] == "--version" || args[1] == "-v") {
        println!("os-tracker {}", env!("CARGO_PKG_VERSION"));
        return;
    }

    let config = load_config();

    log::info!(
        "os-tracker started (os={}, interval={}s)",
        env::consts::OS,
        config.interval_secs
    );

    loop {
        if let Err(err) = send_heartbeat(&config) {
            log::error!("Failed to send heartbeat: {err}");
        }
        thread::sleep(Duration::from_secs(config.interval_secs));
    }
}
