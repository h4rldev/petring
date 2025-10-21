pub mod petads;
pub mod petring;

use super::{
    AdEditRequest, AdResponse, AdSubmission, BulkAdDeleteRequest, BulkAdDeleteResponse,
    BulkUserDeleteRequest, BulkUserDeleteResponse, EditUserResponse, UserEdit, UserResponse,
    UserSubmission, database, jwt, petring_api_err, petring_api_response,
    state::{self, AppState},
};

use axum::{
    Json,
    body::Body,
    extract::State,
    http::{
        HeaderValue, Method, Request, StatusCode,
        header::{AUTHORIZATION, CONTENT_TYPE},
    },
    middleware::Next,
    response::{IntoResponse, Response},
};
use serde::{Deserialize, Serialize};
use tracing::info;

#[derive(Deserialize)]
pub struct BotSetupRequest {
    pub bot_token: String,
}

#[derive(Serialize)]
pub struct BotSetupResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub access_token_expires_at: i64,
    pub refresh_token_expires_at: i64,
}

pub async fn post_bot_setup(
    State(state): State<AppState>,
    Json(bot_setup): Json<BotSetupRequest>,
) -> impl IntoResponse {
    let mut has_generated_jwt = state.has_generated_jwt.lock().await;

    if *has_generated_jwt {
        return petring_api_err(StatusCode::CONFLICT, "Bot already setup");
    }

    let bot_token = bot_setup.bot_token.clone();

    if bot_token != state.bot_token {
        return petring_api_err(StatusCode::UNAUTHORIZED, "Invalid bot token");
    }

    let token_secrets = state.token_secrets.lock().await;
    let access_claims = jwt::Claims::new(&bot_token, jwt::TokenType::Access);
    let access_token = match jwt::generate_token(access_claims.clone(), &token_secrets) {
        Ok(token) => token,
        Err(_) => {
            return petring_api_err(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to generate access token",
            );
        }
    };

    let refresh_claims = jwt::Claims::new(&bot_token, jwt::TokenType::Refresh);
    let refresh_token = match jwt::generate_token(refresh_claims.clone(), &token_secrets) {
        Ok(token) => token,
        Err(_) => {
            return petring_api_err(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to generate refresh token",
            );
        }
    };

    *has_generated_jwt = true;

    petring_api_response(
        StatusCode::OK,
        BotSetupResponse {
            access_token,
            refresh_token,
            access_token_expires_at: access_claims.exp,
            refresh_token_expires_at: refresh_claims.exp,
        },
    )
}

#[derive(Deserialize)]
pub struct BotRefreshRequest {
    pub refresh_token: String,
    pub access_token: String,
}

type BotRefreshResponse = BotSetupResponse;
pub async fn post_refresh_tokens(
    State(state): State<AppState>,
    Json(refresh_request): Json<BotRefreshRequest>,
) -> impl IntoResponse {
    let has_generated_jwt = state.has_generated_jwt.lock().await;

    if !*has_generated_jwt {
        return petring_api_err(StatusCode::NOT_FOUND, "Bot not setup");
    }

    let refresh_token = refresh_request.refresh_token.clone();
    let access_token = refresh_request.access_token.clone();

    let mut token_secrets = state.token_secrets.lock().await;
    let response = match jwt::refresh_token(&refresh_token, &mut token_secrets) {
        Ok(response) => response,
        Err(e) => {
            return petring_api_err(
                StatusCode::INTERNAL_SERVER_ERROR,
                &format!("Failed to refresh token: {e:?}"),
            );
        }
    };

    token_secrets.blacklist_mut().add_token(&access_token);

    petring_api_response(
        StatusCode::OK,
        BotRefreshResponse {
            access_token: response.access_token,
            refresh_token: response.refresh_token,
            access_token_expires_at: response.access_token_expires_in,
            refresh_token_expires_at: response.refresh_token_expires_in,
        },
    )
}

pub async fn require_auth(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> Result<Response, Response> {
    let authorization = request.headers().get(AUTHORIZATION).ok_or(petring_api_err(
        StatusCode::UNAUTHORIZED,
        "No authorization header",
    ))?;

    let content_type = if request.method() != Method::GET {
        request
            .headers()
            .get(CONTENT_TYPE)
            .ok_or(petring_api_err(
                StatusCode::BAD_REQUEST,
                "Missing content type",
            ))?
            .to_str()
            .expect("Invalid content-type")
    } else {
        ""
    };

    let json_content_type = "application/json";

    let token = authorization.to_str().unwrap().split_at(7).1;
    let token_secrets = state.token_secrets.lock().await;
    match jwt::verify_token(token, &token_secrets) {
        Ok(_) => {
            if request.method() != Method::GET && content_type != json_content_type {
                return Err(petring_api_err(
                    StatusCode::BAD_REQUEST,
                    "Wrong content type",
                ));
            }
            Ok(next.run(request).await)
        }
        Err(_) => {
            info!("Failed to verify token, invalid token: {token}");
            Err(petring_api_err(StatusCode::UNAUTHORIZED, "Invalid token"))
        }
    }
}
