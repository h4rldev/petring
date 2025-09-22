use askama::Template;
use axum::{
    Router,
    body::Body,
    extract::Request,
    http::{Response, StatusCode},
    middleware::from_fn_with_state,
    response::{Html, IntoResponse, Response as AxumResponse},
    routing::{delete, get, post, put},
};
use axum_extra::routing::RouterExt;
use petring::{
    IoResult,
    api::{
        bulk_delete_users, delete_user_by_discord_id, delete_user_by_username, get_all_users,
        get_api_index, get_random_user, get_server_info, get_uptime, get_user,
        get_user_by_discord_id, get_user_by_discord_id_unverified, get_user_next, get_user_prev,
        get_user_random, post_bot_setup, post_refresh_tokens, post_user_submit, put_user_edit,
        put_user_verify, require_auth,
    },
    cli::init,
    config::{Level, string_to_ip},
    state::AppState,
};
use std::{convert::Infallible, net::SocketAddr};
use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};
use tower::{ServiceBuilder, service_fn};
use tower_http::{
    CompressionLevel,
    compression::{
        CompressionLayer, Predicate,
        predicate::{NotForContentType, SizeAbove},
    },
    decompression::RequestDecompressionLayer,
    services::ServeDir,
    trace::{DefaultMakeSpan, TraceLayer},
};
#[allow(unused_imports)]
use tracing::{debug, error, info, trace, warn};
use tracing_subscriber::{
    field::MakeExt,
    fmt::{Subscriber, format::debug_fn},
};

use axum_server::tls_rustls::RustlsConfig;

mod petring;

static APP_START: once_cell::sync::Lazy<u64> = once_cell::sync::Lazy::new(|| {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_secs()
});

#[derive(Template)]
#[template(path = "404.html")]
struct NotFoundTemplate {
    path: String,
}

struct HtmlTemplate<T>(T);

impl<T> IntoResponse for HtmlTemplate<T>
where
    T: Template,
{
    fn into_response(self) -> AxumResponse {
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

pub async fn render_404(_req: Request) -> Result<Response<Body>, Infallible> {
    let url = _req.uri().to_string();

    let not_found = NotFoundTemplate { path: url };
    Ok(HtmlTemplate(not_found).into_response())
}

#[tokio::main]
async fn main() -> IoResult<()> {
    let formatter =
        debug_fn(|writer, field, value| write!(writer, "{field}: {value:?}")).delimited(",");

    let config = init();
    let level: Level = config.logging().level.clone().into();

    rustls::crypto::ring::default_provider()
        .install_default()
        .expect("Failed to install rustls crypto provider");

    Subscriber::builder()
        .with_max_level(level.0)
        .fmt_fields(formatter)
        .with_ansi(true)
        .init();

    let root = config.site().root.clone().unwrap_or_else(|| {
        error!("Invalid root path");
        PathBuf::new()
    });

    if !root.exists() {
        warn!("Root path is empty or failed to unwrap, will only resolve 404 page.");
    }

    debug!("root: {root:?}");

    let state = AppState::new().await;

    let compression_predicate = SizeAbove::new(256).and(NotForContentType::IMAGES);

    let serve_public = ServeDir::new(root).not_found_service(service_fn(render_404));

    let user_routes = Router::new()
        .route_with_tsr("/user/{username}", get(get_user))
        .route_with_tsr("/user/{username}/next", get(get_user_next))
        .route_with_tsr("/user/{username}/prev", get(get_user_prev))
        .route_with_tsr("/user/{username}/random", get(get_user_random));

    let protected_routes = Router::new()
        .route_with_tsr(
            "/api/get/user/by-discord/{discord_id}",
            get(get_user_by_discord_id),
        )
        .route_with_tsr(
            "/api/get/user/by-discord/{discord_id}/unverified",
            get(get_user_by_discord_id_unverified),
        )
        .route_with_tsr(
            "/api/delete/user/by-discord/{discord_id}",
            delete(delete_user_by_discord_id),
        )
        .route_with_tsr(
            "/api/delete/user/{username}",
            delete(delete_user_by_username),
        )
        .route_with_tsr("/api/delete/users", delete(bulk_delete_users))
        .route_with_tsr("/api/put/user/edit", put(put_user_edit))
        .route_with_tsr(
            "/api/put/user/verify/{discord_user_id}",
            put(put_user_verify),
        )
        .route_with_tsr("/api/post/user/submit", post(post_user_submit))
        .route_layer(from_fn_with_state(state.clone(), require_auth));

    let bot_routes = Router::new()
        .route_with_tsr("/bot/setup", post(post_bot_setup))
        .route_with_tsr("/bot/refresh", post(post_refresh_tokens));

    let api_routes = Router::new()
        .route_with_tsr("/api", get(get_api_index))
        .route_with_tsr("/api/get/server-info", get(get_server_info))
        .route_with_tsr("/api/get/uptime", get(get_uptime))
        .route_with_tsr("/api/get/users", get(get_all_users))
        .route_with_tsr("/api/get/users/random", get(get_random_user));

    let app = Router::new()
        .fallback_service(serve_public)
        .merge(api_routes)
        .merge(protected_routes)
        .merge(user_routes)
        .merge(bot_routes)
        .layer(
            ServiceBuilder::new()
                .layer(
                    TraceLayer::new_for_http().make_span_with(
                        DefaultMakeSpan::new()
                            .level(tracing::Level::INFO)
                            .include_headers(false),
                    ),
                )
                .layer(RequestDecompressionLayer::new())
                .layer(
                    CompressionLayer::new()
                        .no_br()
                        .no_deflate()
                        .gzip(true)
                        .zstd(true)
                        .quality(CompressionLevel::Fastest)
                        .compress_when(compression_predicate),
                ),
        )
        .with_state(state);
    //
    // This adds compression and decompression to the request and response
    // body streams, don't remove it!
    //

    let ip = string_to_ip(&config.network().ip).unwrap_or_else(|e| panic!("invalid ip: {e}"));
    let addr = SocketAddr::from((ip, config.network().port));

    if config.tls().enable {
        let cert_path = config
            .tls()
            .cert
            .clone()
            .unwrap_or_else(|| panic!("invalid cert path"));
        let key_path = config
            .tls()
            .key
            .clone()
            .unwrap_or_else(|| panic!("invalid key path"));

        let tls_config = RustlsConfig::from_pem_file(cert_path, key_path).await?;
        info!("serving https on {addr}");
        axum_server::bind_rustls(addr, tls_config)
            .serve(app.into_make_service_with_connect_info::<SocketAddr>())
            .await
    } else {
        info!("serving http on {addr}");
        axum_server::bind(addr)
            .serve(app.into_make_service_with_connect_info::<SocketAddr>())
            .await
    }
}
