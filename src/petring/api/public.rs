use super::{
    PetRingResult, PublicAdResponse, Serializeableuser, ServerInfo, UsersResponse,
    database::{
        ads,
        entities::{Ads, Users},
        users,
    },
    petring_api_err, petring_api_response,
    state::AppState,
};
use crate::APP_START;
use axum::{
    extract::{Path, State},
    http::{HeaderMap, HeaderValue, StatusCode, header::LOCATION},
    response::{Html, IntoResponse},
};
use humantime::format_duration;
use rand::{SeedableRng, rngs::StdRng, seq::IndexedRandom};
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder};
use serde::Serialize;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::{fs::File, io::AsyncReadExt};
#[allow(unused_imports)]
use tracing::{debug, error, info};

pub async fn get_public_api_index() -> impl IntoResponse {
    let current_endpoints = [
        "/get/server-info",
        "/get/uptime",
        "/get/users",
        "/get/users/random",
        "/get/random-ad",
    ];

    let wrap_endpoints_with_hyperlinks = current_endpoints
        .iter()
        .map(|endpoint| format!("<li><a href=\"/api{endpoint}\">/api{endpoint}</a></li>"))
        .collect::<Vec<String>>();

    (
        StatusCode::OK,
        Html(format!(
            "<h1>PetRing's shittily hardcoded Public API reference!</h1>
            <p>Use the links below to access the Public API endpoints: <br />
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

pub async fn get_random_ad(State(state): State<AppState>) -> impl IntoResponse {
    let ads = match Ads::find()
        .filter(ads::Column::Verified.eq(true))
        .all(&state.db)
        .await
    {
        Ok(ads) => ads,
        Err(_) => {
            return petring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch ads");
        }
    };

    let ad = match ads.choose(&mut rand::rng()) {
        Some(ad) => ad,
        None => {
            return petring_api_err(StatusCode::NOT_FOUND, "Couldn't pick a random ad");
        }
    };

    petring_api_response(
        StatusCode::OK,
        PublicAdResponse {
            username: ad.username.clone(),
            image_url: ad.image_url.clone(),
            ad_url: ad.ad_url.clone(),
        },
    )
}
