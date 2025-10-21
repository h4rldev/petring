use super::{
    AdEditRequest, AdResponse, AdSubmission, BulkAdDeleteRequest, BulkAdDeleteResponse,
    database::{
        ads,
        entities::{AdModel, Ads, Users},
        users,
    },
    petring_api_err, petring_api_response,
    state::AppState,
};
use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use chrono::Utc;
use sea_orm::{ActiveModelTrait, ColumnTrait, EntityTrait, QueryFilter, Set, prelude::Expr};
use tracing::{error, info};

pub async fn post_ad_submit(
    State(state): State<AppState>,
    Json(submission): Json<AdSubmission>,
) -> impl IntoResponse {
    let user = match Users::find()
        .filter(users::Column::DiscordId.eq(submission.discord_id as i64))
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

    let user = match user {
        Some(user) => user,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "User not found");
        }
    };

    if !user.verified {
        return petring_api_err(StatusCode::NOT_FOUND, "User not verified");
    }

    let does_ad_already_exist = Ads::find()
        .filter(ads::Column::DiscordId.eq(submission.discord_id as i64))
        .one(&state.db)
        .await
        .unwrap_or(None);

    if does_ad_already_exist.is_some() {
        return petring_api_err(StatusCode::CONFLICT, "Ad already exists");
    }

    let image_url = submission.image_url.clone();

    let image_url_parts: Vec<&str> = image_url.split('/').collect();

    let image_url_base_url = format!("{}/{}", image_url_parts[0], image_url_parts[1]);

    let patterns = &[
        "discord",
        "localhost",
        "127.0.0.1",
        "discord",
        "catbox",
        "fileditch",
        "imageshack",
        "google",
        "imgbb",
        "gyazo",
        "twitter",
        "reddit",
        "pixiv",
        "tumblr",
    ];

    let image_url_invalid = patterns
        .iter()
        .any(|pattern| image_url_base_url.contains(pattern));

    if image_url_invalid {
        return petring_api_err(StatusCode::BAD_REQUEST, "Invalid image url");
    }

    let now = Utc::now().to_rfc3339();

    let db_submission = AdModel {
        username: Set(user.username.clone()),
        discord_id: Set(submission.discord_id as i64),
        image_url: Set(submission.image_url.clone()),
        ad_url: Set(user.url.clone()),
        verified: Set(false),
        created_at: Set(now.clone()),
        edited_at: Set("".to_string()),
        verified_at: Set("".to_string()),
        ..Default::default()
    };

    match db_submission.insert(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            AdResponse {
                username: user.username.clone(),
                discord_id: submission.discord_id,
                image_url: submission.image_url.clone(),
                ad_url: user.url.clone(),
                verified: false,
                created_at: now,
                edited_at: "".to_string(),
                verified_at: "".to_string(),
            },
        ),
        Err(e) => petring_api_err(
            StatusCode::INTERNAL_SERVER_ERROR,
            &format!("Failed to insert ad: {e}"),
        ),
    }
}

pub async fn put_ad_verify(
    State(state): State<AppState>,
    Path(discord_id): Path<u64>,
) -> impl IntoResponse {
    let ad = match Ads::find()
        .filter(ads::Column::DiscordId.eq(discord_id as i64))
        .one(&state.db)
        .await
    {
        Ok(ad) => ad,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch ad");
        }
    };

    let ad = match ad {
        Some(ad) => ad,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Ad not found");
        }
    };

    let now = Utc::now().to_rfc3339();
    match Ads::update_many()
        .col_expr(ads::Column::Verified, Expr::value(true))
        .col_expr(ads::Column::VerifiedAt, Expr::value(now.clone()))
        .filter(ads::Column::DiscordId.eq(discord_id as i64))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            AdResponse {
                username: ad.username.clone(),
                discord_id: ad.discord_id as u64,
                image_url: ad.image_url.clone(),
                ad_url: ad.ad_url.clone(),
                verified: true,
                created_at: ad.created_at,
                edited_at: ad.edited_at,
                verified_at: now,
            },
        ),
        Err(e) => petring_api_err(
            StatusCode::INTERNAL_SERVER_ERROR,
            &format!("Failed to verify ad: {e}"),
        ),
    }
}

pub async fn put_ad_edit(
    State(state): State<AppState>,
    Json(submission): Json<AdEditRequest>,
) -> impl IntoResponse {
    let mut editing_url = false;

    let patterns = &[
        "discord",
        "localhost",
        "127.0.0.1",
        "discord",
        "catbox",
        "fileditch",
        "imageshack",
        "google",
        "imgbb",
        "gyazo",
        "twitter",
        "reddit",
        "pixiv",
        "tumblr",
    ];

    let ad = match Ads::find()
        .filter(ads::Column::DiscordId.eq(submission.discord_id))
        .filter(ads::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(ad) => ad,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch ad");
        }
    };

    let ad = match ad {
        Some(ad) => ad,
        None => {
            return petring_api_err(
                StatusCode::NOT_FOUND,
                "Ad not found, are you sure it's verified?",
            );
        }
    };

    let url = if let Some(url) = submission.url {
        editing_url = true;
        url
    } else {
        ad.image_url.clone()
    };

    if editing_url {
        let mut active_ad: AdModel = ad.clone().into();
        let now = Utc::now().to_rfc3339();

        if editing_url && ad.image_url != url {
            let url_parts: Vec<&str> = url.split('/').collect();
            let url_base_url = format!("{}/{}", url_parts[0], url_parts[1]);
            let url_invalid = patterns
                .iter()
                .any(|pattern| url_base_url.contains(pattern));

            if url_invalid {
                return petring_api_err(StatusCode::BAD_REQUEST, "Invalid url");
            }

            active_ad.image_url = Set(url.clone());
        }

        active_ad.edited_at = Set(now.clone());

        match active_ad.update(&state.db).await {
            Ok(_) => {
                info!("Updated ad for {}", ad.username);
                return petring_api_response(
                    StatusCode::OK,
                    AdResponse {
                        username: ad.username,
                        discord_id: ad.discord_id as u64,
                        image_url: url,
                        ad_url: ad.ad_url,
                        verified: ad.verified,
                        created_at: ad.created_at,
                        edited_at: now,
                        verified_at: ad.verified_at,
                    },
                );
            }
            Err(err) => {
                error!("Failed to update ad for {}: {err}", ad.username);
                return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to update ad");
            }
        }
    }

    petring_api_err(StatusCode::NOT_MODIFIED, "No changes made")
}

pub async fn delete_ad_by_discord_id(
    State(state): State<AppState>,
    Path(discord_id): Path<u64>,
) -> impl IntoResponse {
    let ad = match Ads::find()
        .filter(ads::Column::DiscordId.eq(discord_id as i64))
        .one(&state.db)
        .await
    {
        Ok(ad) => ad,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch ad");
        }
    };

    let ad = match ad {
        Some(ad) => ad,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Ad not found");
        }
    };

    match Ads::delete_by_id(ad.id).exec(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            AdResponse {
                username: ad.username.clone(),
                discord_id: ad.discord_id as u64,
                image_url: ad.image_url.clone(),
                ad_url: ad.ad_url.clone(),
                verified: ad.verified,
                created_at: ad.created_at,
                edited_at: ad.edited_at,
                verified_at: ad.verified_at,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete ad"),
    }
}

pub async fn delete_ad_by_username(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let ad = match Ads::find()
        .filter(ads::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(ad) => ad,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch ad");
        }
    };

    let ad = match ad {
        Some(ad) => ad,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Ad not found");
        }
    };

    match Ads::delete_by_id(ad.id).exec(&state.db).await {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            AdResponse {
                username: ad.username.clone(),
                discord_id: ad.discord_id as u64,
                image_url: ad.image_url.clone(),
                ad_url: ad.ad_url.clone(),
                verified: ad.verified,
                created_at: ad.created_at,
                edited_at: ad.edited_at,
                verified_at: ad.verified_at,
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete ad"),
    }
}

pub async fn bulk_delete_ads(
    State(state): State<AppState>,
    Json(bulk_delete_request): Json<BulkAdDeleteRequest>,
) -> impl IntoResponse {
    let mut ads_to_delete = Vec::new();

    if let Some(discord_ids) = bulk_delete_request.discord_ids {
        for discord_id in discord_ids {
            let ad = match Ads::find()
                .filter(ads::Column::DiscordId.eq(discord_id as i64))
                .one(&state.db)
                .await
            {
                Ok(ad) => ad,
                Err(_) => {
                    return petring_api_err(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to fetch ad",
                    );
                }
            };

            let ad = match ad {
                Some(ad) => ad,
                None => {
                    return petring_api_err(StatusCode::NOT_FOUND, "Ad not found");
                }
            };

            ads_to_delete.push(ad);
        }
    }
    if let Some(usernames) = bulk_delete_request.usernames {
        for username in usernames {
            let ad = match Ads::find()
                .filter(ads::Column::Username.eq(username))
                .one(&state.db)
                .await
            {
                Ok(ad) => ad,
                Err(_) => {
                    return petring_api_err(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to fetch ad",
                    );
                }
            };

            let ad = match ad {
                Some(ad) => ad,
                None => {
                    return petring_api_err(StatusCode::NOT_FOUND, "Ad not found");
                }
            };
            if !ads_to_delete.contains(&ad) {
                ads_to_delete.push(ad);
            }
        }
    }

    match Ads::delete_many()
        .filter(ads::Column::Id.is_in(ads_to_delete.iter().map(|ad| ad.id)))
        .exec(&state.db)
        .await
    {
        Ok(_) => petring_api_response(
            StatusCode::OK,
            BulkAdDeleteResponse {
                message: "Ads deleted".to_string(),
                discord_ids: ads_to_delete
                    .iter()
                    .map(|ad| ad.discord_id as u64)
                    .collect(),
                usernames: ads_to_delete.iter().map(|ad| ad.username.clone()).collect(),
                image_urls: ads_to_delete
                    .iter()
                    .map(|ad| ad.image_url.clone())
                    .collect(),
            },
        ),
        Err(_) => petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to delete ads"),
    }
}
