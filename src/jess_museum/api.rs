use super::{WebringResult, state::AppState};
use crate::{
    APP_START,
    jess_museum::database::{entities::Members, members},
};
use askama::Template;
use axum::{
    Json,
    body::Body,
    extract::{Path, State},
    http::{
        HeaderMap, HeaderValue, StatusCode,
        header::{CONTENT_DISPOSITION, CONTENT_LENGTH, CONTENT_TYPE, LOCATION},
    },
    response::{Html, IntoResponse, Redirect, Response},
};
use humantime::format_duration;
use sea_orm::{ColumnTrait, EntityTrait, QueryFilter, QueryOrder, QuerySelect, Set};
use serde::Serialize;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::{fs::File, io::AsyncReadExt};

#[derive(Template)]
#[template(path = "iframe.html")]
struct HelloTemplate {
    name: String,
}

struct HtmlTemplate<T>(T);

impl<T> IntoResponse for HtmlTemplate<T>
where
    T: Template,
{
    fn into_response(self) -> Response {
        match self.0.render() {
            Ok(html) => Html(html).into_response(),
            Err(err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Failed to render template. Error: {err}"),
            )
                .into_response(),
        }
    }
}

#[derive(Serialize)]
pub(crate) struct CremeBruleeApiResponse {
    pub status: u16,
    pub message: String,
}

pub(crate) fn webring_api_err(status: StatusCode, message: &str) -> Response<Body> {
    (
        status,
        Json(CremeBruleeApiResponse {
            status: status.as_u16(),
            message: message.to_string(),
        }),
    )
        .into_response()
}

pub(crate) fn webring_api_response<T: Serialize>(status: StatusCode, message: T) -> Response<Body> {
    (status, Json(message)).into_response()
}

pub async fn get_api_index() -> impl IntoResponse {
    let current_endpoints = ["/server-info", "/uptime"];

    let wrap_endpoints_with_hyperlinks = current_endpoints
        .iter()
        .map(|endpoint| format!("<li><a href=\"/api{endpoint}\">/api{endpoint}</a></li>"))
        .collect::<Vec<String>>();

    (
        StatusCode::OK,
        Html(format!(
            "<h1>Creme Brulee's shittily hardcoded public api reference</h1>
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

async fn get_app_uptime() -> WebringResult<Duration> {
    Ok(Duration::from_secs(
        SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() - *APP_START,
    ))
}

async fn get_system_uptime() -> WebringResult<Duration> {
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

    webring_api_response(
        StatusCode::OK,
        ServerInfo {
            name: "The Jess Museum Webring".to_string(),
            version: "0.0.1".to_string(),
            description: "A Webring for the Jess Museum Discord server".to_string(),
            source: "https://github.com/h4rldev/jess-webring".to_string(),
            authors: ["h4rl".to_string(), "Jess Museum".to_string()],
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
        eprintln!("Error getting app uptime: {}", e);
        Duration::new(0, 0)
    });

    let system_uptime = get_system_uptime().await.unwrap_or_else(|e| {
        eprintln!("Error getting system uptime: {}", e);
        Duration::new(0, 0)
    });

    webring_api_response(
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

pub async fn get_member(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let member = match Members::find()
        .filter(members::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(member) => member,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch member");
        }
    };

    let member = match member {
        Some(member) => member,
        None => {
            return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&member.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_member_next(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let member = match Members::find()
        .filter(members::Column::Username.eq(username))
        .one(&state.db)
        .await
    {
        Ok(member) => member,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch member");
        }
    };

    let member = match member {
        Some(member) => member,
        None => {
            return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
        }
    };

    let is_last = match Members::find()
        .order_by_desc(members::Column::Id)
        .one(&state.db)
        .await
    {
        Ok(member) => member,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch member");
        }
    };

    let is_last = match is_last {
        Some(member) => member,
        None => {
            return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
        }
    };

    let next_member = if is_last.id != member.id {
        let _next_member = match Members::find()
            .order_by_asc(members::Column::Id)
            .filter(members::Column::Id.gt(member.id))
            .one(&state.db)
            .await
        {
            Ok(member) => member,
            Err(_) => {
                return webring_api_err(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to fetch member",
                );
            }
        };

        match _next_member {
            Some(member) => member,
            None => {
                return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
            }
        }
    } else {
        let _next_member = match Members::find()
            .order_by_asc(members::Column::Id)
            .one(&state.db)
            .await
        {
            Ok(member) => member,
            Err(_) => {
                return webring_api_err(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to fetch member",
                );
            }
        };

        match _next_member {
            Some(member) => member,
            None => {
                return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
            }
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&next_member.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

pub async fn get_member_prev(
    State(state): State<AppState>,
    Path(username): Path<String>,
) -> impl IntoResponse {
    let member = match Members::find()
        .filter(members::Column::Username.eq(username))
        .filter(members::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(member) => member,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch member");
        }
    };

    let member = match member {
        Some(member) => member,
        None => {
            return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
        }
    };

    let is_first = match Members::find()
        .order_by_asc(members::Column::Id)
        .filter(members::Column::Verified.eq(true))
        .one(&state.db)
        .await
    {
        Ok(member) => member,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch member");
        }
    };

    let is_first = match is_first {
        Some(member) => member,
        None => {
            return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
        }
    };

    let prev_member = if is_first.id != member.id {
        let _prev_member = match Members::find()
            .order_by_desc(members::Column::Id)
            .filter(members::Column::Id.lt(member.id))
            .filter(members::Column::Verified.eq(true))
            .one(&state.db)
            .await
        {
            Ok(member) => member,
            Err(_) => {
                return webring_api_err(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to fetch member",
                );
            }
        };

        match _prev_member {
            Some(member) => member,
            None => {
                return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
            }
        }
    } else {
        let _prev_member = match Members::find()
            .order_by_desc(members::Column::Id)
            .filter(members::Column::Verified.eq(true))
            .one(&state.db)
            .await
        {
            Ok(member) => member,
            Err(_) => {
                return webring_api_err(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Failed to fetch member",
                );
            }
        };

        match _prev_member {
            Some(member) => member,
            None => {
                return webring_api_err(StatusCode::NOT_FOUND, "Member not found");
            }
        }
    };

    let mut headermap = HeaderMap::new();
    headermap.insert(
        LOCATION,
        HeaderValue::from_str(&prev_member.url).expect("Failed to insert header"),
    );

    (StatusCode::TEMPORARY_REDIRECT, headermap).into_response()
}

#[derive(Serialize)]
pub struct SerializeableMember {
    pub username: String,
    pub url: String,
}

#[derive(Serialize)]
pub struct MembersResponse {
    pub members: Vec<SerializeableMember>,
}

pub async fn get_all_members(State(state): State<AppState>) -> impl IntoResponse {
    let members = match Members::find()
        .filter(members::Column::Verified.eq(true))
        .all(&state.db)
        .await
    {
        Ok(members) => members,
        Err(_) => {
            return webring_api_err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to fetch members");
        }
    };

    webring_api_response(
        StatusCode::OK,
        MembersResponse {
            members: members
                .iter()
                .map(|member| SerializeableMember {
                    username: member.username.clone(),
                    url: member.url.clone(),
                })
                .collect(),
        },
    )
}
