use super::config::Config;
use clap::Parser;

use std::{path::PathBuf, process::exit};
use tracing::info;

#[derive(Parser, Debug)]
#[clap(
    author = "h4rl",
    version,
    about = "A simple, fast and flexible web server template written in Rust with help of axum",
    help_template = r#"
{name} v{version} by {author}
{about}

{usage-heading} {usage}

{all-args}
"#
)]
pub struct Cli {
    #[clap(short, long, default_value = "creme-brulee.toml")]
    pub config: PathBuf,
    #[clap(short, long, help = "Toggle TLS")]
    pub tls: bool,
    #[clap(short, long, help = "Port to listen on")]
    pub port: Option<u16>,
    #[clap(short, long, help = "IP to listen on")]
    pub ip: Option<String>,
    #[clap(short, long, help = "Generate a COOKIE_SECRET")]
    pub generate_cookie_secret: bool,
}

pub fn init() -> Config {
    let cli = Cli::parse();

    let mut config = Config::load_from_file(&cli.config)
        .unwrap_or_else(|e| panic!("failed to load config: {e}"));

    config.tls.enable = cli.tls;
    info!("tls: {}", cli.tls);

    if let Some(port) = cli.port {
        config.network.port = port;
        info!("port: {}", config.network.port);
    }

    if let Some(ip) = cli.ip {
        config.network.ip = ip;
        info!("ip: {}", config.network.ip);
    }

    if cli.generate_cookie_secret {
        let cookie = axum_extra::extract::cookie::Key::generate();
        let master = cookie.master();
        let master = master
            .iter()
            .map(|c| c.to_ascii_lowercase().to_string())
            .collect::<String>();
        println!(
            "COOKIE_SECRET: \"{}\" (Don't share this with anyone, and don't forget to set it in your .env file)",
            master
        );
        exit(0);
    }

    config
}
