use dotenvy::dotenv;
use sea_orm::{ConnectOptions, DatabaseConnection};

#[derive(Clone)]
pub struct AppState {
    pub db: DatabaseConnection,
}

/* State for the admin endpoints */

impl AppState {
    pub async fn new() -> Self {
        dotenv().ok();

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

        Self { db }
    }
}
