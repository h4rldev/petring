use dotenvy::dotenv;
use sea_orm::{ConnectOptions, DatabaseConnection};
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::petring::jwt::TokenSecrets;

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
    pub has_generated_jwt: Arc<Mutex<bool>>,
    pub bot_token: String,
    pub token_secrets: Arc<Mutex<TokenSecrets>>,
}

/* State for the admin endpoints */

impl AppState {
    pub async fn new() -> Self {
        dotenv().ok();

        let bot_token = std::env::var("BOT_TOKEN").expect("BOT_TOKEN must be set");

        let mut connection_opts =
            ConnectOptions::new(std::env::var("DATABASE_URL").expect("DATABASE_URL must be set"));

        connection_opts
            .sqlx_logging(true)
            .sqlx_logging_level(tracing::log::LevelFilter::Warn)
            .max_connections(20)
            .min_connections(5)
            .connect_timeout(std::time::Duration::from_secs(30))
            .acquire_timeout(std::time::Duration::from_secs(30));

        let db = sea_orm::Database::connect(connection_opts)
            .await
            .expect("Failed to connect to database");

        let token_secrets = TokenSecrets::new();

        Self {
            db,
            has_generated_jwt: Arc::new(Mutex::new(false)),
            bot_token,
            token_secrets: Arc::new(Mutex::new(token_secrets)),
        }
    }
}
