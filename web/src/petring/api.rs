use super::{PetRingResult, state::AppState};
use crate::APP_START;
use axum::{
    Json,
    body::Body,
    extract::{Path, State},
    http::{HeaderMap, HeaderValue, Response, StatusCode, header::LOCATION},
    response::{Html, IntoResponse},
};
use humantime::format_duration;
use serde::Serialize;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::{fs::File, io::AsyncReadExt};
use tracing::error;

#[derive(Serialize)]
pub(crate) struct PetRingApiResponse {
    pub status: u16,
    pub message: String,
}

#[derive(Serialize)]
struct ServerInfo {
    name: String,
    version: String,
    description: String,
    authors: [String; 2],
    license: String,
    source: String,
    server_uptime: String,
    system_uptime: String,
}

#[derive(Serialize)]
struct ApiUrlResponse {
    api_url: String,
}

pub(crate) fn petring_api_err(status: StatusCode, message: &str) -> Response<Body> {
    (
        status,
        Json(PetRingApiResponse {
            status: status.as_u16(),
            message: message.to_string(),
        }),
    )
        .into_response()
}

pub(crate) fn petring_api_response<T: Serialize>(status: StatusCode, message: T) -> Response<Body> {
    (status, Json(message)).into_response()
}

pub async fn get_public_api_index(State(state): State<AppState>) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    let current_endpoints = ["/get/server-info", "/get/uptime", "/get/api-url"];

    let wrap_endpoints_with_hyperlinks = current_endpoints
        .iter()
        .map(|endpoint| format!("<li><a href=\"/api{endpoint}\">/api{endpoint}</a></li>"))
        .collect::<Vec<String>>();

    (
        StatusCode::OK,
        Html(format!(
            "<h1>PetRing's shittily hardcoded Public API reference!</h1>
            <p>This one is \"quite small\", check out the other one <a href=\"{api_base_url}\">here</a></p>
            <p>Use the links below to access the Public API endpoints: <br />
            <small>(None of these need authentication, so you can simply access them by going to <code>/api/&lcub;endpoint&rcub;</code> in your browser.)</small>
            </p>
            <p>Current endpoints:</p>
            <ul>
              {}
            </ul>",
            wrap_endpoints_with_hyperlinks.join("\n")
        )),
    )
}

async fn get_app_uptime() -> PetRingResult<Duration> {
    Ok(Duration::from_secs(
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() - *APP_START,
    ))
}

async fn get_system_uptime() -> PetRingResult<Duration> {
    let mut contents = String::new();
    let mut file = File::open("/proc/uptime").await?;

    file.read_to_string(&mut contents).await?;

    let uptime: f64 = contents
        .split_whitespace()
        .next()
        .ok_or("No data in /proc/uptime")?
        .parse()?;

    if uptime < 0.0 {
        return Err("Uptime cannot be negative".into());
    }

    if uptime > f64::MAX {
        return Err("Uptime exceeds maximum value".into());
    }

    Ok(Duration::from_secs_f64(uptime))
}

pub async fn get_server_info() -> impl IntoResponse {
    let app_uptime = get_app_uptime().await.unwrap_or_else(|e| {
        eprintln!("Error getting app uptime: {}", e);
        Duration::new(0, 0)
    });

    let system_uptime = get_system_uptime().await.unwrap_or_else(|e| {
        eprintln!("Error getting system uptime: {}", e);
        Duration::new(0, 0)
    });

    petring_api_response(
        StatusCode::OK,
        ServerInfo {
            name: "petring".to_string(),
            version: "0.1.0".to_string(),
            description: "A webring for the Jess Museum Discord server".to_string(),
            source: "https://github.com/h4rldev/petring".to_string(),
            authors: ["h4rl".to_string(), "doloro".to_string()],
            license: "BSD 3-Clause License".to_string(),
            server_uptime: format_duration(app_uptime).to_string(),
            system_uptime: format_duration(system_uptime).to_string(),
        },
    )
}

#[derive(Serialize)]
struct UptimeResponse {
    app_uptime: String,
    system_uptime: String,
}

pub async fn get_uptime() -> impl IntoResponse {
    let app_uptime = get_app_uptime().await.unwrap_or_else(|e| {
        error!("Error getting app uptime: {}", e);
        Duration::new(0, 0)
    });

    let system_uptime = get_system_uptime().await.unwrap_or_else(|e| {
        error!("Error getting system uptime: {}", e);
        Duration::new(0, 0)
    });

    petring_api_response(
        StatusCode::OK,
        UptimeResponse {
            app_uptime: format_duration(app_uptime).to_string(),
            system_uptime: format_duration(system_uptime).to_string(),
        },
    )
}

pub async fn get_user(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    if api_base_url.is_empty() {
        return petring_api_err(StatusCode::NOT_FOUND, "API base URL is empty");
    }

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&format!("{api_base_url}/get/users/{username}"))
            .expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_next(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    if api_base_url.is_empty() {
        return petring_api_err(StatusCode::NOT_FOUND, "API base URL is empty");
    }

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&format!("{api_base_url}/get/users/{username}/next"))
            .expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_prev(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    if api_base_url.is_empty() {
        return petring_api_err(StatusCode::NOT_FOUND, "API base URL is empty");
    }

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&format!("{api_base_url}/get/users/{username}/prev"))
            .expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_random(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    if api_base_url.is_empty() {
        return petring_api_err(StatusCode::NOT_FOUND, "API base URL is empty");
    }

    let url = format!("{api_base_url}/get/users/{username}/random");

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_api_url(State(state): State<AppState>) -> impl IntoResponse {
    let api_base_url = state.api_base_url.lock().await;
    if api_base_url.is_empty() {
        return petring_api_err(StatusCode::NOT_FOUND, "API base URL is empty");
    }

    petring_api_response(
        StatusCode::OK,
        ApiUrlResponse {
            api_url: api_base_url.clone(),
        },
    )
}
