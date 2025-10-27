use axum::{
  Router,
  body::Body,
  extract::Request,
  http::{
    Method, Response, StatusCode,
    header::{ACCEPT, AUTHORIZATION, CONTENT_TYPE},
  },
};
use petring::{
  IoResult,
  api::{
    petring_api_err,
    routes::{bot_routes, protected_routes, public_routes},
  },
  config::Config,
  config::{Level, string_to_ip},
  state::AppState,
};
use std::{
  convert::Infallible,
  net::SocketAddr,
  time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::{signal, time::sleep};
use tower::{ServiceBuilder, service_fn};
use tower_http::{
  CompressionLevel,
  compression::{
    CompressionLayer, Predicate,
    predicate::{NotForContentType, SizeAbove},
  },
  cors::{AllowOrigin, CorsLayer},
  decompression::RequestDecompressionLayer,
  trace::{DefaultMakeSpan, TraceLayer},
};
use tracing::info;
use tracing_subscriber::{
  field::MakeExt,
  fmt::{Subscriber, format::debug_fn},
};

use axum_server::{Handle, tls_rustls::RustlsConfig};

mod petring;

static APP_START: once_cell::sync::Lazy<u64> = once_cell::sync::Lazy::new(|| {
  SystemTime::now()
    .duration_since(UNIX_EPOCH)
    .expect("Time went backwards")
    .as_secs()
});

pub async fn render_404(_req: Request) -> Result<Response<Body>, Infallible> {
  let url = _req.uri().to_string();
  let message = format!("The requested resource at {url} could not be found.");

  Ok(petring_api_err(StatusCode::NOT_FOUND, &message))
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

  let level: Level = config.logging().level.clone().into();

  rustls::crypto::ring::default_provider()
    .install_default()
    .expect("Failed to install rustls crypto provider");

  Subscriber::builder()
    .with_max_level(level.0)
    .fmt_fields(formatter)
    .with_ansi(true)
    .init();

  let handle = Handle::new();
  tokio::spawn(shutdown_signal(handle.clone()));

  let state = AppState::new().await;
  let compression_predicate = SizeAbove::new(256).and(NotForContentType::IMAGES);
  let cors_public = if cfg!(debug_assertions) {
    CorsLayer::new()
      .allow_origin(AllowOrigin::any())
      .allow_methods([
        Method::GET,
        Method::POST,
        Method::PATCH,
        Method::DELETE,
        Method::HEAD,
      ])
      .allow_headers([ACCEPT, CONTENT_TYPE, AUTHORIZATION])
      .max_age(Duration::from_secs(60 * 60 * 24 * 7))
  } else {
    CorsLayer::new()
      .allow_origin(AllowOrigin::any())
      .allow_methods([Method::GET, Method::HEAD])
      .allow_headers([ACCEPT, CONTENT_TYPE])
      .max_age(Duration::from_secs(60 * 60 * 24))
  };

  let public_routes = public_routes();
  let protected_routes = protected_routes(state.clone());
  let bot_routes = bot_routes();

  let app = Router::new()
    .fallback_service(service_fn(render_404))
    .merge(public_routes)
    .layer(cors_public)
    .merge(protected_routes)
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

  let ip = string_to_ip(&config.network().ip).unwrap_or_else(|e| panic!("Invalid ip: {e}"));
  let addr = SocketAddr::from((ip, config.network().port));
  let tls = config.tls().clone();

  if tls.enable {
    let cert_path = tls.cert.unwrap_or_else(|| panic!("Invalid cert path"));
    let key_path = tls.key.unwrap_or_else(|| panic!("Invalid key path"));

    let tls_config = RustlsConfig::from_pem_file(cert_path, key_path).await?;
    info!("Serving HTTPS on {addr}");
    axum_server::bind_rustls(addr, tls_config)
      .handle(handle)
      .serve(app.into_make_service_with_connect_info::<SocketAddr>())
      .await
  } else {
    info!("Serving HTTP on {addr}");
    axum_server::bind(addr)
      .handle(handle)
      .serve(app.into_make_service_with_connect_info::<SocketAddr>())
      .await
  }
}

async fn shutdown_signal(handle: Handle) {
  let ctrl_c = async {
    signal::ctrl_c()
      .await
      .expect("failed to install Ctrl+C handler");
  };

  let terminate = async {
    signal::unix::signal(signal::unix::SignalKind::terminate())
      .expect("failed to install signal handler")
      .recv()
      .await;
  };

  tokio::select! {
      _ = ctrl_c => {},
      _ = terminate => {},
  }

  eprintln!("\n");
  tracing::info!("Received CTRL-C shutting down gracefully");
  handle.graceful_shutdown(Some(Duration::from_secs(10)));
  loop {
    sleep(Duration::from_secs(1)).await;
    info!("alive connections: {}", handle.connection_count());
  }
}
