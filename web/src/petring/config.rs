use serde::{Deserialize, Serialize};
use std::{fmt, fs, path::PathBuf};
use tracing::Level as TracingLevel;

use super::{IoResult, PetRingResult};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Level(pub TracingLevel);

impl Level {
    pub const TRACE: tracing::Level = tracing::Level::TRACE;
    pub const DEBUG: tracing::Level = tracing::Level::DEBUG;
    pub const INFO: tracing::Level = tracing::Level::INFO;
    pub const WARN: tracing::Level = tracing::Level::WARN;
    pub const ERROR: tracing::Level = tracing::Level::ERROR;
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct Config {
    pub site: SiteConfig,
    pub tls: TlsConfig,
    pub network: NetworkConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SiteConfig {
    pub root: Option<PathBuf>,
    pub api_base_url: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct TlsConfig {
    pub cert: Option<PathBuf>,
    pub key: Option<PathBuf>,
    /* pub quic: bool, */ // Uncomment when QUIC support is added
    pub enable: bool,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct NetworkConfig {
    pub ip: String,
    pub port: u16,
    // Add quic support when quic is implemented
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct LoggingConfig {
    pub level: String,
}

impl fmt::Display for Level {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self.0 {
            Self::TRACE => write!(f, "TRACE"),
            Self::DEBUG => write!(f, "DEBUG"),
            Self::INFO => write!(f, "INFO"),
            Self::WARN => write!(f, "WARN"),
            Self::ERROR => write!(f, "ERROR"),
        }
    }
}

impl From<&str> for Level {
    fn from(s: &str) -> Self {
        match s {
            "TRACE" => Self(Self::TRACE),
            "DEBUG" => Self(Self::DEBUG),
            "INFO" => Self(Self::INFO),
            "WARN" => Self(Self::WARN),
            "ERROR" => Self(Self::ERROR),
            _ => panic!("invalid level"),
        }
    }
}

impl From<tracing::Level> for Level {
    fn from(level: tracing::Level) -> Self {
        Self(level)
    }
}

impl From<String> for Level {
    fn from(s: String) -> Self {
        Self::from(s.as_str())
    }
}

impl From<Level> for tracing::Level {
    fn from(level: Level) -> Self {
        level.0
    }
}

impl Config {
    pub fn load() -> PetRingResult<Self> {
        let config = match fs::read_to_string("petring-web.toml") {
            Ok(config) => config,
            Err(e) => {
                if e.kind() == std::io::ErrorKind::NotFound {
                    let config = Config::default();
                    config.write()?;
                    return Ok(config);
                }
                return Err(e.into());
            }
        };

        let config: Config = toml::from_str(&config)?;

        Ok(config)
    }

    pub fn site(&self) -> &SiteConfig {
        &self.site
    }

    pub fn tls(&self) -> &TlsConfig {
        &self.tls
    }

    pub fn network(&self) -> &NetworkConfig {
        &self.network
    }

    pub fn logging(&self) -> &LoggingConfig {
        &self.logging
    }

    pub fn default() -> Self {
        Self {
            site: SiteConfig {
                root: Some(PathBuf::from("static")),
                api_base_url: Some(String::from("http://localhost:8081")),
            },
            tls: TlsConfig {
                cert: None,
                key: None,
                // quic: false,
                enable: false,
            },
            network: NetworkConfig {
                ip: "0.0.0.0".to_string(),
                port: 8080,
                // quic_port: None,
            },
            logging: LoggingConfig {
                level: "INFO".to_string(),
            },
        }
    }

    pub fn write(&self) -> IoResult<()> {
        let config = match toml::to_string_pretty(self) {
            Ok(config) => config,
            Err(e) => panic!("Couldn't serialize config: {e}"),
        };

        fs::write("petring-web.toml", config)?;
        Ok(())
    }
}

pub fn string_to_ip(ip: &str) -> Result<[u8; 4], String> {
    let mut ip_bytes = [0; 4];
    let ip = ip.split('.').collect::<Vec<&str>>();
    if ip.len() != 4 {
        return Err(format!("invalid ip address: {:?}", ip));
    }
    for (i, byte) in ip.iter().enumerate() {
        let byte = byte
            .parse::<u8>()
            .map_err(|_| format!("invalid ip address: {:?}", ip))?;
        ip_bytes[i] = byte;
    }
    Ok(ip_bytes)
}
