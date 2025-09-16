use axum::{
    Router,
    body::Body,
    extract::Request,
    http::{Response, StatusCode},
    response::{Html, IntoResponse},
    routing::get,
};
use jess_museum::{
    IoResult,
    api::{get_api_index, get_member, get_server_info, get_uptime},
    cli::init,
    config::{Level, string_to_ip},
};
use std::{convert::Infallible, net::SocketAddr};
use std::{
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};
use tower::{ServiceBuilder, service_fn};
use tower_http::{
    compression::{
        Predicate,
        predicate::{NotForContentType, SizeAbove},
    },
    services::{ServeDir, ServeFile},
};
#[allow(unused_imports)]
use tracing::{debug, error, info, trace, warn};
use tracing_subscriber::{
    field::MakeExt,
    fmt::{Subscriber, format::debug_fn},
};

mod jess_museum;
use axum_server::tls_rustls::RustlsConfig;

use crate::jess_museum::{
    api::{get_all_members, get_member_next, get_member_prev},
    state::AppState,
};

static APP_START: once_cell::sync::Lazy<u64> = once_cell::sync::Lazy::new(|| {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards")
        .as_secs()
});

pub async fn render_404(_req: Request) -> Result<Response<Body>, Infallible> {
    let url = _req.uri().to_string();

    Ok((
        StatusCode::NOT_FOUND,
        Html(format!(
            "
      <h1>404 Not Found</h1>
      <p>The requested resource at {url} could not be found.</p>
      "
        )),
    )
        .into_response())
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

    let error_page = config.site().error.clone().unwrap_or_else(|| {
        error!("Invalid error page path");
        PathBuf::new()
    });

    if !error_page.exists() || error_page.as_os_str().is_empty() {
        warn!("Error page path is empty or failed to unwrap, Using hardcoded fallback error page.");
    }

    debug!("root: {root:?}");
    debug!("error page: {error_page:?}");

    let state = AppState::new().await;

    let compression_predicate = SizeAbove::new(256).and(NotForContentType::IMAGES);

    let serve_public = ServeDir::new(root)
        .not_found_service(ServeFile::new(error_page.clone()))
        .fallback(service_fn(render_404));

    let user_routes = Router::new()
        .route("/{username}", get(get_member))
        .route("/{username}/next", get(get_member_next))
        .route("/{username}/prev", get(get_member_prev));

    let api_routes = Router::new()
        .route("/", get(get_api_index))
        .route("/server-info", get(get_server_info))
        .route("/uptime", get(get_uptime))
        .route("/members", get(get_all_members));

    let app = Router::new()
        .layer(
            ServiceBuilder::new()
                .layer(tower_http::decompression::RequestDecompressionLayer::new())
                .layer(
                    tower_http::compression::CompressionLayer::new()
                        .zstd(true)
                        .gzip(true)
                        .no_br()
                        .no_deflate()
                        .compress_when(compression_predicate),
                ),
        )
        .layer(tower_http::normalize_path::NormalizePathLayer::trim_trailing_slash())
        .fallback_service(serve_public)
        .nest("/api", api_routes)
        .nest("/user", user_routes)
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
