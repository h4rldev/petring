use std::sync::Arc;
use tokio::sync::Mutex;

#[derive(Clone)]
pub struct AppState {
    pub api_base_url: Arc<Mutex<String>>,
}

/* State for the admin endpoints */

impl AppState {
    pub fn new(api_base_url: String) -> Self {
        Self {
            api_base_url: Arc::new(Mutex::new(api_base_url)),
        }
    }
}
