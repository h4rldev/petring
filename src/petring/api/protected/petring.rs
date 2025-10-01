use super::{
    database::{
        entities::{UserModel, Users},
        users,
    },
    petring_api_err, petring_api_response,
    state::AppState,
    BulkUserDeleteRequest, BulkUserDeleteResponse, EditUserResponse, UserEdit, UserResponse,
    UserSubmission,
};
use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use sea_orm::{prelude::Expr, ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set};
#[allow(unused_imports)]
use tracing::{debug, error, info};

pub async fn get_user_by_discord_id(
    State(state): State<AppState>,
    Path(discord_id): Path<u64>,
) -> impl IntoResponse {
    let user_by_discord = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_id as i64))
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
            discord_id: user_by_discord.discord_id as u64,
            verified: user_by_discord.verified,
            created_at: user_by_discord.created_at,
            edited_at: user_by_discord.edited_at,
            verified_at: user_by_discord.verified_at,
        },
    )
}

pub async fn get_user_by_discord_id_unverified(
    State(state): State<AppState>,
    Path(discord_id): Path<u64>,
) -> impl IntoResponse {
    let user_by_discord = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_id as i64))
        .one(&state.db)
        .await
    {
        Ok(user) => user,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch user");
        }
    };

    let user_by_discord = match user_by_discord {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    petring_api_response(
        StatusCode::OK,
        UserResponse {
            username: user_by_discord.username.clone(),
            url: user_by_discord.url.clone(),
            discord_id: user_by_discord.discord_id as u64,
            verified: false,
            created_at: user_by_discord.created_at,
            edited_at: user_by_discord.edited_at,
            verified_at: user_by_discord.verified_at,
        },
    )
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
            UserResponse {
                username: user.username.clone(),
                url: user.url.clone(),
                discord_id: user.discord_id as u64,
                verified: user.verified,
                created_at: user.created_at,
                edited_at: user.edited_at,
                verified_at: user.verified_at,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete user"),
    }
}

pub async fn delete_user_by_discord_id(
    State(state): State<AppState>,
    Path(discord_id): Path<u64>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_id as i64))
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
            UserResponse {
                username: user.username.clone(),
                url: user.url.clone(),
                discord_id: user.discord_id as u64,
                verified: user.verified,
                created_at: user.created_at,
                edited_at: user.edited_at,
                verified_at: user.verified_at,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete user"),
    }
}

pub async fn bulk_delete_users(
    State(state): State<AppState>,
    Json(bulk_delete_request): Json<BulkUserDeleteRequest>,
) -> impl IntoResponse {
    let mut users_to_delete = Vec::new();

    if let Some(discord_ids) = bulk_delete_request.discord_ids {
        for discord_id in discord_ids {
            let user = match Users::find()
                .filter(users::Column::DiscordId.eq(discord_id as i64))
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
            if !users_to_delete.contains(&user) {
                users_to_delete.push(user);
            }
        }
    }

    match Users::delete_many()
        .filter(users::Column::Id.is_in(users_to_delete.iter().map(|user| user.id)))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            BulkUserDeleteResponse {
                message: "Users deleted".to_string(),
                discord_ids: users_to_delete
                    .iter()
                    .map(|user| user.discord_id as u64)
                    .collect(),
                usernames: users_to_delete
                    .iter()
                    .map(|user| user.username.clone())
                    .collect(),
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete users"),
    }
}

pub async fn put_user_verify(
    State(state): State<AppState>,
    Path(discord_user_id): Path<u64>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(discord_user_id as i64))
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

    let now = Utc::now().to_rfc3339();
    match Users::update_many()
        .col_expr(users::Column::Verified, Expr::value(true))
        .col_expr(users::Column::VerifiedAt, Expr::value(now.clone()))
        .filter(users::Column::DiscordId.eq(discord_user_id as i64))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            UserResponse {
                username: user.username.clone(),
                url: user.url.clone(),
                discord_id: user.discord_id as u64,
                verified: true,
                created_at: user.created_at,
                edited_at: user.edited_at,
                verified_at: now,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to update user"),
    }
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
        .filter(users::Column::DiscordId.eq(submission.discord_id as i64))
        .one(&state.db)
        .await
        .unwrap_or(None);

    if user.is_some() {
        return petring_api_err(StatusCode::CONFLICT, "User already exists");
    }

    let now = Utc::now().to_rfc3339();

    let db_submission = UserModel {
        username: Set(submission.username.clone()),
        discord_id: Set(submission.discord_id as i64),
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

pub async fn put_user_edit(
    State(state): State<AppState>,
    Json(submission): Json<UserEdit>,
) -> impl IntoResponse {
    let mut editing_name = false;
    let mut editing_url = false;

    let patterns = &[
        "discord",
        "localhost",
        "127.0.0.1",
        "google",
        "twitter",
        "x.com",
        "reddit",
        "pixiv",
        "tumblr",
        "facebook",
        "instagram",
        "youtube",
        "tiktok",
        "snapchat",
        "pinterest",
        "github",
        "gitlab",
        "bitbucket",
        "medium",
        "linkedin",
        "stackoverflow",
        "stackexchange",
    ];

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
            let url_parts: Vec<&str> = url.split('/').collect();
            let url_base_url = format!("{}/{}", url_parts[0], url_parts[1]);
            let url_invalid = patterns
                .iter()
                .any(|pattern| url_base_url.contains(pattern));

            if url_invalid {
                return petring_api_err(StatusCode::BAD_REQUEST, "Invalid url");
            }

            active_user.url = Set(url.clone());
        }

        active_user.edited_at = Set(now.clone());

        match active_user.update(&state.db).await {
            Ok(_) => {
                info!("Updated user: {username}");
                return petring_api_response(
                    StatusCode::OK,
                    EditUserResponse {
                        old: UserResponse {
                            username: user.username.clone(),
                            url: user.url.clone(),
                            discord_id: user.discord_id as u64,
                            verified: user.verified,
                            created_at: user.created_at.clone(),
                            edited_at: user.edited_at,
                            verified_at: user.verified_at.clone(),
                        },
                        new: UserResponse {
                            username,
                            url,
                            discord_id: user.discord_id as u64,
                            verified: true,
                            created_at: user.created_at,
                            edited_at: now,
                            verified_at: user.verified_at,
                        },
                    },
                );
            }
            Err(_) => {
                error!("Failed to update user: {username}");
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to update user");
            }
        }
    }

    petring_api_err(StatusCode::NOT_MODIFIED, "No changes made")
}
