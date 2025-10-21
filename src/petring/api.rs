use super::{PetRingResult, database, jwt, state};

use axum::{
    Json,
    body::Body,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::{Deserialize, Serialize};
#[allow(unused_imports)]
use tracing::{debug, error, info};

pub mod protected;
pub mod public;

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
struct PublicAdResponse {
    pub username: String,
    pub image_url: String,
    pub ad_url: String,
}

#[derive(Serialize)]
struct UserResponse {
    username: String,
    discord_id: u64,
    url: String,
    verified: bool,
    created_at: String,
    edited_at: String,
    verified_at: String,
}

#[derive(Serialize)]
struct EditUserResponse {
    old: UserResponse,
    new: UserResponse,
}

#[derive(Serialize)]
pub struct Serializeableuser {
    pub username: String,
    pub url: String,
}

#[derive(Serialize)]
pub struct UsersResponse {
    pub users: Vec<Serializeableuser>,
}

#[derive(Deserialize)]
pub struct AdSubmission {
    pub image_url: String,
    pub discord_id: u64,
}

#[derive(Serialize)]
pub struct AdResponse {
    pub username: String,
    pub discord_id: u64,
    pub image_url: String,
    pub ad_url: String,
    pub verified: bool,
    pub created_at: String,
    pub edited_at: String,
    pub verified_at: String,
}

#[derive(Deserialize)]
pub struct AdEditRequest {
    pub discord_id: u64,
    pub url: Option<String>,
}

#[derive(Deserialize)]
pub struct BulkUserDeleteRequest {
    pub discord_ids: Option<Vec<u64>>,
    pub usernames: Option<Vec<String>>,
}

#[derive(Serialize)]
pub struct BulkUserDeleteResponse {
    pub message: String,
    pub discord_ids: Vec<u64>,
    pub usernames: Vec<String>,
}

pub type BulkAdDeleteRequest = BulkUserDeleteRequest;

#[derive(Serialize)]
pub struct BulkAdDeleteResponse {
    pub message: String,
    pub discord_ids: Vec<u64>,
    pub usernames: Vec<String>,
    pub image_urls: Vec<String>,
}

#[derive(Deserialize)]
pub struct UserSubmission {
    pub username: String,
    pub url: String,
    pub discord_id: u64,
}

#[derive(Deserialize)]
pub struct UserEdit {
    pub discord_id: u64,
    pub username: Option<String>,
    pub url: Option<String>,
}

#[derive(Serialize)]
pub(crate) struct PetRingApiResponse {
    pub status: u16,
    pub message: String,
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
