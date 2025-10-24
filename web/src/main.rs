use askama::Template;
use axum::{
    Router,
    body::Body,
    extract::Request,
    http::{
        HeaderValue, Method, Response, StatusCode,
        header::{self, CACHE_CONTROL, CONTENT_SECURITY_POLICY},
    },
    response::{Html, IntoResponse, Response as AxumResponse},
    routing::get,
};
use axum_extra::routing::RouterExt;
use axum_server::tls_rustls::RustlsConfig;
use petring::{
    IoResult, api,
    config::{Config, Level, string_to_ip},
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
use tracing::{info, warn};
use tracing_subscriber::{
    field::MakeExt,
    fmt::{Subscriber, format::debug_fn},
};

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

    let config = match Config::load() {
        Ok(config) => config,
        Err(e) => {
            panic!("Failed to load config: {e}");
        }
    };

    let site = config.site().clone();
    let logging = config.logging().clone();
    let level: Level = logging.level.into();
    let level: tracing::Level = level.into();

    rustls::crypto::ring::default_provider()
        .install_default()
        .expect("Failed to install rustls crypto provider");

    Subscriber::builder()
        .with_max_level(level)
        .fmt_fields(formatter)
        .with_ansi(true)
        .init();

    let root = if let Some(root) = site.root {
        root
    } else {
        PathBuf::new()
    };

    let api_base_url = site.api_base_url.unwrap_or_default();

    if api_base_url.is_empty() {
        warn!("API base URL is empty, wont be able to resolve.");
    }

    if !root.exists() || !root.is_dir() {
        warn!("Root path is empty or failed to unwrap, will only resolve 404 page.");
    }

    let state = AppState::new(api_base_url);
    let compression_predicate = SizeAbove::new(256).and(NotForContentType::IMAGES);
    let cors = CorsLayer::new()
        .allow_origin(AllowOrigin::any())
        .allow_methods([Method::GET, Method::HEAD])
        .allow_headers([header::CONTENT_TYPE])
        .max_age(Duration::from_secs(60 * 60 * 24));

    let serve_public = ServeDir::new(root).not_found_service(service_fn(render_404));

    let user_routes = Router::new()
        .route_with_tsr("/user/{username}", get(api::get_user))
        .route_with_tsr("/user/{username}/next", get(api::get_user_next))
        .route_with_tsr("/user/{username}/prev", get(api::get_user_prev))
        .route_with_tsr("/user/{username}/random", get(api::get_user_random))
        .layer(cors.clone());

    let api_routes = Router::new()
        .route_with_tsr("/api/", get(api::get_public_api_index))
        .route_with_tsr("/api/get/server-info", get(api::get_server_info))
        .route_with_tsr("/api/get/uptime", get(api::get_uptime))
        .route_with_tsr("/api/get/api-url", get(api::get_api_url))
        .layer(cors.clone());

    let app = Router::new()
        .fallback_service(serve_public)
        .merge(api_routes)
        .merge(user_routes)
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
                .layer(cors),
        )
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
        ).with_state(state);
    //
    // This adds compression and decompression to the request and response
    // body streams, don't remove it!
    //

    let ip = string_to_ip(&config.network().ip).unwrap_or_else(|e| panic!("Invalid ip: {e}"));
    let addr = SocketAddr::from((ip, config.network().port));

    if config.tls().enable {
        let cert_path = config
            .tls()
            .cert
            .clone()
            .unwrap_or_else(|| panic!("Invalid cert path"));
        let key_path = config
            .tls()
            .key
            .clone()
            .unwrap_or_else(|| panic!("Invalid key path"));

        let tls_config = RustlsConfig::from_pem_file(cert_path, key_path).await?;
        info!("Serving HTTPS on {addr}");
        axum_server::bind_rustls(addr, tls_config)
            .serve(app.into_make_service_with_connect_info::<SocketAddr>())
            .await
    } else {
        info!("Serving HTTP on {addr}");
        axum_server::bind(addr)
            .serve(app.into_make_service_with_connect_info::<SocketAddr>())
            .await
    }
}
