pub(crate) mod api;
pub(crate) mod cli;
pub(crate) mod config;
pub(crate) mod database;
pub(crate) mod jwt;
pub(crate) mod state;

pub(crate) type IoResult<T> = std::io::Result<T>;
pub(crate) type WebringError = Box<dyn std::error::Error>;
pub(crate) type WebringResult<T> = Result<T, WebringError>;
