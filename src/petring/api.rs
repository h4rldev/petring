use super::{
    PetRingResult,
    database::{
        entities::{UserModel, Users},
        users,
    },
    state::AppState,
};
use crate::{APP_START, petring::jwt};

use axum::{
    Json,
    body::Body,
    extract::{Path, State},
    http::{
        HeaderMap, HeaderValue, Request, StatusCode,
        header::{self, LOCATION},
    },
    middleware::Next,
    response::{Html, IntoResponse, Response},
};
use chrono::Utc;
use humantime::format_duration;
use rand::{SeedableRng, rngs::StdRng, seq::IndexedRandom};
use sea_orm::{
    ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, QueryOrder, Set, prelude::Expr,
};
use serde::{Deserialize, Serialize};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::{fs::File, io::AsyncReadExt};
#[allow(unused_imports)]
use tracing::{debug, error, info};

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

pub async fn get_api_index() -> impl IntoResponse {
    let current_endpoints = [
        "/get/server-info",
        "/get/uptime",
        "/get/users",
        "/get/users/random",
    ];

    let wrap_endpoints_with_hyperlinks = current_endpoints
        .iter()
        .map(|endpoint| format!("<li><a href=\"/api{endpoint}\">/api{endpoint}</a></li>"))
        .collect::<Vec<String>>();

    (
        StatusCode::OK,
        Html(format!(
            "<h1>petring's shittily hardcoded public api reference!</h1>
            <p>Use the links below to access the API endpoints: <br />
            <small>(None of these need authentication, so you can simply access them by going to <code>/api/&lcub;endpoint&rcub;</code> in your browser.)</small>
            </p>
            <p>Note: The API is still under development, so some endpoints may not work as expected.</p>
            <p>Current endpoints:</p>
            <ul>
              {}
            </ul>",
            wrap_endpoints_with_hyperlinks.join("\n")
        )),
    )
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
            version: "0.0.1".to_string(),
            description: "A webring for the Jess Museum Discord server".to_string(),
            source: "https://github.com/h4rldev/petring".to_string(),
            authors: ["h4rl".to_string(), "doloro".to_string()],
            license: "Undecided".to_string(),
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

/* GET /user/{username}
 *
 */

pub async fn get_user(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&user.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_next(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let is_last = match Users::find()
        .order_by_desc(users::Column::Id)
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let is_last = match is_last {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let next_user = if is_last.id != user.id {
        let _next_user = match Users::find()
            .order_by_asc(users::Column::Id)
            .filter(users::Column::Id.gt(user.id))
            .one(&state.db)
            .await
        {
            Ok(user) => user,
            Err(_) => {
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
            }
        };

        match _next_user {
            Some(user) => user,
            None => {
                return petring_api_err(StatusCode::NOT_FOUND, "User not found");
            }
        }
    } else {
        let _next_user = match Users::find()
            .order_by_asc(users::Column::Id)
            .one(&state.db)
            .await
        {
            Ok(user) => user,
            Err(_) => {
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
            }
        };

        match _next_user {
            Some(user) => user,
            None => {
                return petring_api_err(StatusCode::NOT_FOUND, "User not found");
            }
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&next_user.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_prev(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::Username.eq(username))
        .filter(users::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let is_first = match Users::find()
        .order_by_asc(users::Column::Id)
        .filter(users::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let is_first = match is_first {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let prev_user = if is_first.id != user.id {
        let _prev_user = match Users::find()
            .order_by_desc(users::Column::Id)
            .filter(users::Column::Id.lt(user.id))
            .filter(users::Column::Verified.eq(true))
            .one(&state.db)
            .await
        {
            Ok(user) => user,
            Err(_) => {
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
            }
        };

        match _prev_user {
            Some(user) => user,
            None => {
                return petring_api_err(StatusCode::NOT_FOUND, "User not found");
            }
        }
    } else {
        let _prev_user = match Users::find()
            .order_by_desc(users::Column::Id)
            .filter(users::Column::Verified.eq(true))
            .one(&state.db)
            .await
        {
            Ok(user) => user,
            Err(_) => {
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
            }
        };

        match _prev_user {
            Some(user) => user,
            None => {
                return petring_api_err(StatusCode::NOT_FOUND, "User not found");
            }
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&prev_user.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_user_random(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let current_user = match Users::find()
        .filter(users::Column::Username.eq(username))
        .filter(users::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let current_user = match current_user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Couldn't pick a random user");
        }
    };

    let user_seed = current_user.id << 16 | current_user.id;
    let user_seed = user_seed as u64;
    let mut rng = StdRng::seed_from_u64(user_seed);

    let users = match Users::find()
        .filter(users::Column::Verified.eq(true))
        .all(&state.db)
        .await
    {
        Ok(users) => users,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match users.choose(&mut rng) {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Couldn't pick a random user");
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&user.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
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

pub async fn get_all_users(State(state): State<AppState>) -> impl IntoResponse {
    let users = match Users::find()
        .filter(users::Column::Verified.eq(true))
        .all(&state.db)
        .await
    {
        Ok(users) => users,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch users");
        }
    };

    petring_api_response(
        StatusCode::OK,
        UsersResponse {
            users: users
                .iter()
                .map(|user| Serializeableuser {
                    username: user.username.clone(),
                    url: user.url.clone(),
                })
                .collect(),
        },
    )
}

pub async fn get_random_user(State(state): State<AppState>) -> impl IntoResponse {
    let users = match Users::find()
        .filter(users::Column::Verified.eq(true))
        .all(&state.db)
        .await
    {
        Ok(users) => users,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch users");
        }
    };

    let user = match users.choose(&mut rand::rng()) {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Couldn't pick a random user");
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&user.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

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
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to refresh token");
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

#[derive(Serialize)]
struct UserResponse {
    username: String,
    discord_id: i64,
    url: String,
    verified: bool,
    created_at: String,
    edited_at: String,
    verified_at: String,
}

pub async fn get_user_by_discord_id(
    State(state): State<AppState>,
    Path(discord_id): Path<i64>,
) -> impl IntoResponse {
    let user_by_discord = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_id))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to fetch user, does it exist?",
            );
        }
    };

    let user_by_discord = match user_by_discord {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    if !user_by_discord.verified {
        return petring_api_err(StatusCode::NOT_FOUND, "User not verified");
    }

    petring_api_response(
        StatusCode::OK,
        UserResponse {
            username: user_by_discord.username.clone(),
            url: user_by_discord.url.clone(),
            discord_id: user_by_discord.discord_id,
            verified: user_by_discord.verified,
            created_at: user_by_discord.created_at,
            edited_at: user_by_discord.edited_at,
            verified_at: user_by_discord.verified_at,
        },
    )
}

#[derive(Serialize)]
pub struct DeleteuserResponse {
    pub message: String,
}

pub async fn delete_user_by_username(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    match Users::delete_by_id(user.id).exec(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            DeleteuserResponse {
                message: "user deleted".to_string(),
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete user"),
    }
}

pub async fn delete_user_by_discord_id(
    State(state): State<AppState>,
    Path(discord_id): Path<i64>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_id))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    match Users::delete_by_id(user.id).exec(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            DeleteuserResponse {
                message: "user deleted".to_string(),
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete user"),
    }
}

#[derive(Deserialize)]
pub struct BulkDeleteRequest {
    pub discord_ids: Option<Vec<i64>>,
    pub usernames: Option<Vec<String>>,
}

pub async fn bulk_delete_users(
    State(state): State<AppState>,
    Json(bulk_delete_request): Json<BulkDeleteRequest>,
) -> impl IntoResponse {
    let mut users_to_delete = Vec::new();

    if let Some(discord_ids) = bulk_delete_request.discord_ids {
        for discord_id in discord_ids {
            let user = match Users::find()
                .filter(users::Column::DiscordId.eq(discord_id))
                .one(&state.db)
                .await
            {
                Ok(user) => user,
                Err(_) => {
                    return petring_api_err(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to fetch user",
                    );
                }
            };

            let user = match user {
                Some(user) => user,
                None => {
                    return petring_api_err(StatusCode::NOT_FOUND, "User not found");
                }
            };

            users_to_delete.push(user);
        }
    }

    if let Some(usernames) = bulk_delete_request.usernames {
        for username in usernames {
            let user = match Users::find()
                .filter(users::Column::Username.eq(username))
                .one(&state.db)
                .await
            {
                Ok(user) => user,
                Err(_) => {
                    return petring_api_err(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to fetch user",
                    );
                }
            };

            let user = match user {
                Some(user) => user,
                None => {
                    return petring_api_err(StatusCode::NOT_FOUND, "User not found");
                }
            };

            users_to_delete.push(user);
        }
    }

    match Users::delete_many()
        .filter(users::Column::Id.is_in(users_to_delete.iter().map(|user| user.id)))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            DeleteuserResponse {
                message: "users deleted".to_string(),
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete users"),
    }
}

pub async fn put_user_verify(
    State(state): State<AppState>,
    Path(discord_user_id): Path<i64>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_user_id))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    match Users::update_many()
        .col_expr(users::Column::Verified, Expr::value(true))
        .col_expr(
            users::Column::VerifiedAt,
            Expr::value(Utc::now().to_rfc3339()),
        )
        .filter(users::Column::DiscordId.eq(discord_user_id))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            UserResponse {
                username: user.username.clone(),
                url: user.url.clone(),
                discord_id: user.discord_id,
                verified: true,
                created_at: user.created_at,
                edited_at: user.edited_at,
                verified_at: user.verified_at,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to update user"),
    }
}

#[derive(Deserialize)]
pub struct UserSubmission {
    pub username: String,
    pub url: String,
    pub discord_id: i64,
}

pub async fn post_user_submit(
    State(state): State<AppState>,
    Json(submission): Json<UserSubmission>,
) -> impl IntoResponse {
    let sanitize_username = submission
        .username
        .clone()
        .replace(" ", "_")
        .replace(".", "_");

    let user = Users::find()
        .filter(users::Column::Username.eq(sanitize_username.clone()))
        .one(&state.db)
        .await
        .unwrap_or(None);

    if user.is_some() {
        return petring_api_err(StatusCode::CONFLICT, "User already exists");
    }

    let user = Users::find()
        .filter(users::Column::DiscordId.eq(submission.discord_id))
        .one(&state.db)
        .await
        .unwrap_or(None);

    if user.is_some() {
        return petring_api_err(StatusCode::CONFLICT, "User already exists");
    }

    let now = Utc::now().to_rfc3339();

    let db_submission = UserModel {
        username: Set(submission.username.clone()),
        discord_id: Set(submission.discord_id),
        url: Set(submission.url.clone()),
        verified: Set(false),
        created_at: Set(now.clone()),
        edited_at: Set("".to_string()),
        verified_at: Set("".to_string()),
        ..Default::default()
    };

    match db_submission.insert(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            UserResponse {
                username: submission.username.clone(),
                discord_id: submission.discord_id,
                url: submission.url.clone(),
                verified: false,
                created_at: now,
                edited_at: "".to_string(),
                verified_at: "".to_string(),
            },
        ),
        Err(e) => petring_api_err(
            StatusCode::INTERNAL_SERVER_ERROR,
            &format!("Failed to insert user: {e}"),
        ),
    }
}

#[derive(Deserialize)]
pub struct UserEdit {
    pub discord_id: i64,
    pub username: Option<String>,
    pub url: Option<String>,
}

pub async fn put_user_edit(
    State(state): State<AppState>,
    Json(submission): Json<UserEdit>,
) -> impl IntoResponse {
    let mut editing_name = false;
    let mut editing_url = false;

    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(submission.discord_id))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    let username = if let Some(username) = submission.username {
        editing_name = true;
        username
    } else {
        user.username.clone()
    };

    let url = if let Some(url) = submission.url {
        editing_url = true;
        url
    } else {
        user.url.clone()
    };

    if editing_name || editing_url {
        let mut active_user: UserModel = user.clone().into();
        let now = Utc::now().to_rfc3339();

        if editing_name && user.username != username {
            active_user.username = Set(username.clone());
        }

        if editing_url && user.url != url {
            active_user.url = Set(url.clone());
        }

        active_user.edited_at = Set(now.clone());

        match active_user.update(&state.db).await {
            Ok(_) => {
                return petring_api_response(
                    StatusCode::OK,
                    UserResponse {
                        username,
                        discord_id: user.discord_id,
                        url,
                        verified: user.verified,
                        created_at: user.created_at,
                        edited_at: now,
                        verified_at: user.verified_at,
                    },
                );
            }
            Err(_) => {
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to update user");
            }
        }
    }

    petring_api_err(StatusCode::NOT_MODIFIED, "No changes made")
}

pub async fn require_auth(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> Result<Response, Response> {
    let headers = request
        .headers()
        .get(header::AUTHORIZATION)
        .ok_or(petring_api_err(
            StatusCode::UNAUTHORIZED,
            "No authorization header",
        ))?;

    let token = headers.to_str().unwrap().split_at(7).1;
    info!("token: {token}");
    let token_secrets = state.token_secrets.lock().await;
    match jwt::verify_token(token, &token_secrets) {
        Ok(_) => Ok(next.run(request).await),
        Err(_) => {
            info!("Failed to verify token, invalid token: {token}");
            Err(petring_api_err(StatusCode::UNAUTHORIZED, "Invalid token"))
        }
    }
}
