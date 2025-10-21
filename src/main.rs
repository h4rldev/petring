use askama::Template;
use axum::{
    Router,
    body::Body,
    extract::Request,
    http::{
        HeaderValue, Method, Response, StatusCode,
        header::{self, CACHE_CONTROL, CONTENT_SECURITY_POLICY},
    },
    middleware::from_fn_with_state,
    response::{Html, IntoResponse, Response as AxumResponse},
    routing::{delete, get, patch, post},
};
use axum_extra::routing::RouterExt;
use petring::{
    IoResult,
    api::{
        protected::{self, petads, petring as petring_protected},
        public,
    },
    cli::init,
    config::{Level, string_to_ip},
    state::AppState,
};
use std::{
    convert::Infallible,
    net::SocketAddr,
    path::PathBuf,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tower::{ServiceBuilder, service_fn};
use tower_http::{
    CompressionLevel,
    compression::{
        CompressionLayer, Predicate,
        predicate::{NotForContentType, SizeAbove},
    },
    cors::{AllowOrigin, CorsLayer},
    decompression::RequestDecompressionLayer,
    services::ServeDir,
    set_header::SetResponseHeaderLayer,
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

pub struct HtmlTemplate<T>(T);

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
    let cors_public = if cfg!(debug_assertions) {
        CorsLayer::new()
            .allow_origin(AllowOrigin::any())
            .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
            .allow_headers([header::ACCEPT, header::CONTENT_TYPE, header::AUTHORIZATION])
            .max_age(Duration::from_secs(60 * 60 * 24 * 7))
    } else {
        CorsLayer::new()
            .allow_origin(AllowOrigin::any())
            .allow_methods([Method::GET])
            .allow_headers([header::ACCEPT, header::CONTENT_TYPE])
            .max_age(Duration::from_secs(60 * 60 * 24))
    };

    let cors_protected = CorsLayer::new()
        .allow_origin(AllowOrigin::any())
        .allow_methods([Method::GET, Method::POST, Method::PATCH, Method::DELETE])
        .allow_headers([header::ACCEPT, header::CONTENT_TYPE, header::AUTHORIZATION])
        .max_age(Duration::from_secs(60 * 60 * 24 * 7));

    let serve_public = ServeDir::new(root).not_found_service(service_fn(render_404));

    let user_routes = Router::new()
        .route_with_tsr("/user/{username}", get(public::get_user))
        .route_with_tsr("/user/{username}/next", get(public::get_user_next))
        .route_with_tsr("/user/{username}/prev", get(public::get_user_prev))
        .route_with_tsr("/user/{username}/random", get(public::get_user_random))
        .layer(cors_public.clone());

    let protected_routes = Router::new()
        .route_with_tsr(
            "/api/get/user/by-discord/{discord_id}",
            get(petring_protected::get_user_by_discord_id),
        )
        .route_with_tsr(
            "/api/get/user/by-discord/{discord_id}/unverified",
            get(petring_protected::get_user_by_discord_id_unverified),
        )
        .route_with_tsr(
            "/api/delete/user/by-discord/{discord_id}",
            delete(petring_protected::delete_user_by_discord_id),
        )
        .route_with_tsr(
            "/api/delete/user/{username}",
            delete(petring_protected::delete_user_by_username),
        )
        .route_with_tsr(
            "/api/delete/users",
            delete(petring_protected::bulk_delete_users),
        )
        .route_with_tsr(
            "/api/patch/user/edit",
            patch(petring_protected::patch_user_edit),
        )
        .route_with_tsr(
            "/api/patch/user/verify/{discord_user_id}",
            patch(petring_protected::patch_user_verify),
        )
        .route_with_tsr(
            "/api/post/user/submit",
            post(petring_protected::post_user_submit),
        )
        .route_with_tsr("/api/post/ad/submit", post(petads::post_ad_submit))
        .route_with_tsr(
            "/api/patch/ad/verify/{discord_user_id}",
            patch(petads::patch_ad_verify),
        )
        .route_with_tsr("/api/patch/ad/edit", patch(petads::patch_ad_edit))
        .route_with_tsr(
            "/api/delete/ad/by-discord/{discord_id}",
            delete(petads::delete_ad_by_discord_id),
        )
        .route_with_tsr(
            "/api/delete/ad/{username}",
            delete(petads::delete_ad_by_username),
        )
        .route_with_tsr("/api/delete/ads", delete(petads::bulk_delete_ads))
        .route_layer(from_fn_with_state(state.clone(), protected::require_auth))
        .layer(cors_protected.clone());

    let bot_routes = Router::new()
        .route_with_tsr("/bot/setup", post(protected::post_bot_setup))
        .route_with_tsr("/bot/refresh", post(protected::post_refresh_tokens))
        .layer(cors_protected);

    let api_routes = Router::new()
        .route_with_tsr("/api", get(public::get_public_api_index))
        .route_with_tsr("/api/get/server-info", get(public::get_server_info))
        .route_with_tsr("/api/get/uptime", get(public::get_uptime))
        .route_with_tsr("/api/get/users", get(public::get_all_users))
        .route_with_tsr("/api/get/users/random", get(public::get_random_user))
        .route_with_tsr("/api/get/random-ad", get(public::get_random_ad))
        .layer(cors_public.clone());

    let app = Router::new()
        .fallback_service(serve_public)
        .layer(
            ServiceBuilder::new()
                .layer(SetResponseHeaderLayer::if_not_present(
                    CACHE_CONTROL,
                    HeaderValue::from_static("max-age=604800"),
                ))
                .layer(SetResponseHeaderLayer::if_not_present(
                    CONTENT_SECURITY_POLICY,
                    HeaderValue::from_static("default-src 'self'; script-src 'self'; script-src-elem 'self'; style-src 'self' 'unsafe-inline'; img-src * data:; connect-src 'self' https://http.cat https://http.dog; frame-src 'self' https://discord.com;"),
                ))
                .layer(cors_public),
        )
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
