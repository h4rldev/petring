pub(crate) mod api;
pub(crate) mod cli;
pub(crate) mod config;
pub(crate) mod database;
pub(crate) mod jwt;
pub(crate) mod state;

pub(crate) type IoResult<T> = std::io::Result<T>;
pub(crate) type PetRingError = Box<dyn std::error::Error>;
pub(crate) type PetRingResult<T> = Result<T, PetRingError>;
