use super::{
  protected::{petads, petring, post_bot_setup, post_refresh_tokens, require_auth},
  public,
  state::AppState,
};
use axum::{
  Router,
  http::{Method, header},
  middleware::from_fn_with_state,
  routing::{delete, get, patch, post},
};
use axum_extra::routing::RouterExt;
use std::time::Duration;
use tower_http::cors::{AllowOrigin, CorsLayer};

pub fn protected_routes(state: AppState) -> Router<AppState> {
  let cors_protected = CorsLayer::new()
    .allow_origin(AllowOrigin::any())
    .allow_methods([
      Method::GET,
      Method::POST,
      Method::PATCH,
      Method::DELETE,
      Method::HEAD,
    ])
    .allow_headers([header::ACCEPT, header::CONTENT_TYPE, header::AUTHORIZATION])
    .max_age(Duration::from_secs(60 * 60 * 24 * 7));

  let protected_user_routes = Router::new()
    .route_with_tsr(
      "/get/user/by-discord/{discord_id}",
      get(petring::get_user_by_discord_id),
    )
    .route_with_tsr("/get/users/unverified", get(petring::get_unverified_users))
    .route_with_tsr(
      "/delete/user/by-discord/{discord_id}",
      delete(petring::delete_user_by_discord_id),
    )
    .route_with_tsr(
      "/delete/user/{username}",
      delete(petring::delete_user_by_username),
    )
    .route_with_tsr("/delete/users", delete(petring::delete_users_by_bulk))
    .route_with_tsr("/patch/user/edit", patch(petring::patch_user_edit))
    .route_with_tsr(
      "/patch/user/verify/{discord_user_id}",
      patch(petring::patch_user_verify),
    )
    .route_with_tsr("/post/user/submit", post(petring::post_user_submit));

  let protected_ad_routes = Router::new()
    .route_with_tsr("/get/ad/{discord_id}", get(petads::get_ad))
    .route_with_tsr("/get/ads/unverified", get(petads::get_unverified_ads))
    .route_with_tsr("/post/ad/submit", post(petads::post_ad_submit))
    .route_with_tsr(
      "/patch/ad/verify/{discord_user_id}",
      patch(petads::patch_ad_verify),
    )
    .route_with_tsr("/patch/ad/edit", patch(petads::patch_ad_edit))
    .route_with_tsr(
      "/delete/ad/by-discord/{discord_id}",
      delete(petads::delete_ad_by_discord_id),
    )
    .route_with_tsr(
      "/delete/ad/{username}",
      delete(petads::delete_ad_by_username),
    )
    .route_with_tsr("/delete/ads", delete(petads::delete_ads_by_bulk));

  Router::new()
    .merge(protected_user_routes)
    .merge(protected_ad_routes)
    .route_layer(from_fn_with_state(state, require_auth))
    .layer(cors_protected)
}

pub fn public_routes() -> Router<AppState> {
  let api_routes = Router::new()
    .route_with_tsr("/get/users/random", get(public::get_random_user))
    .route_with_tsr("/get/random-ad", get(public::get_random_ad))
    .route_with_tsr("/get/server-info", get(public::get_server_info))
    .route_with_tsr("/get/uptime", get(public::get_uptime));

  let user_routes = Router::new()
    .route_with_tsr("/get/users", get(public::get_all_users))
    .route_with_tsr("/get/user/{username}", get(public::get_user))
    .route_with_tsr("/get/user/{username}/next", get(public::get_user_next))
    .route_with_tsr("/get/user/{username}/prev", get(public::get_user_prev))
    .route_with_tsr("/get/user/{username}/random", get(public::get_user_random));

  Router::new()
    .route("/", get(public::get_public_api_index))
    .merge(api_routes)
    .merge(user_routes)
}

pub fn bot_routes() -> Router<AppState> {
  let cors_protected = CorsLayer::new()
    .allow_origin(AllowOrigin::any())
    .allow_methods([
      Method::GET,
      Method::POST,
      Method::PATCH,
      Method::DELETE,
      Method::HEAD,
    ])
    .allow_headers([header::ACCEPT, header::CONTENT_TYPE, header::AUTHORIZATION])
    .max_age(Duration::from_secs(60 * 60 * 24 * 7));

  Router::new()
    .route_with_tsr("/bot/setup", post(post_bot_setup))
    .route_with_tsr("/bot/refresh", post(post_refresh_tokens))
    .layer(cors_protected)
}
