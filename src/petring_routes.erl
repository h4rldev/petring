-module (petring_routes).
-export ([get/0]).

-spec get() -> Routes :: [errm_http:route()].
get() ->
  [
    {get, [":path*"], errm_http_file:serve_dir("site-root", ["index.html", "index.htm"], "200.html")},

    {get, ["user", ":name"], fun petring_public:get_user/1},
    {get, ["user", ":name", "next"], fun petring_public:user_next/1},
    {get, ["user", ":name", "prev"], fun petring_public:user_prev/1},
    {get, ["user", ":name", "random"], fun petring_public:user_random/1},

    {get, ["api"], fun petring_public:index/1},
    {get, ["api", "server-info"], fun petring_public:server_info/1},
    {get, ["api", "uptime"], fun petring_public:uptime/1},
    {get, ["api", "users"], fun petring_public:get_users/1},
    {get, ["api", "users", "random"], fun petring_public:random_user/1},
    {get, ["api", "random-ad"], fun petring_public:random_ad/1},
    {get, ["api", "user", ":name"], fun petring_public:get_user/1},
    {get, ["api", "user", ":name", "next"], fun petring_public:user_next/1},
    {get, ["api", "user", ":name", "prev"], fun petring_public:user_prev/1},
    {get, ["api", "user", ":name", "random"], fun petring_public:user_random/1},

    {get, ["newsletter", "feed.xml"], fun petring_newsletter:feed/1},

    {get, ["api", "newsletter"], fun petring_newsletter:list/1},
    {get, ["api", "newsletter", "ws"], fun petring_newsletter_ws:upgrade/1},
    {get, ["api", "newsletter", ":id"], fun petring_newsletter:get/1},

    {post, ["api", "users"], fun petring_users:submit/1},

    {get, ["api", "manage"], fun petring_manage:get/1},
    {patch, ["api", "manage"], fun petring_manage:update/1},
    {delete, ["api", "manage"], fun petring_manage:delete/1},
    {get, ["api", "manage", "ad"], fun petring_manage:get_ad/1},
    {post, ["api", "manage", "ad"], fun petring_manage:create_ad/1},
    {patch, ["api", "manage", "ad"], fun petring_manage:update_ad/1},
    {delete, ["api", "manage", "ad"], fun petring_manage:delete_ad/1},

    {post, ["api", "admin", "login"], fun petring_auth:login/1},
    {get, ["api", "admin", "logout"], fun petring_auth:logout/1},
    {get, ["api", "admin", "me"], fun petring_auth:me/1},
    {get, ["api", "admin", "accounts"], fun petring_auth:list_accounts/1},
    {post, ["api", "admin", "accounts"], fun petring_auth:create_account/1},
    {delete, ["api", "admin", "accounts", ":name"], fun petring_auth:delete_account/1},
    {post, ["api", "admin", "accounts", ":name", "password"], fun petring_auth:change_password/1},

    {get, ["api", "admin", "users", "unverified"], fun petring_admin:unverified_users/1},
    {get, ["api", "admin", "ads", "unverified"], fun petring_admin:unverified_ads/1},
    {post, ["api", "admin", "users", ":name", "verify"], fun petring_admin:verify_user/1},
    {post, ["api", "admin", "ads", ":name", "verify"], fun petring_admin:verify_ad/1},
    {delete, ["api", "admin", "users", ":name"], fun petring_admin:delete_user/1},
    {delete, ["api", "admin", "ads", ":name"], fun petring_admin:delete_ad/1},
    {get, ["api", "admin", "blocked-words", ":scope"], fun petring_admin:get_blocked_words/1},
    {put, ["api", "admin", "blocked-words", ":scope"], fun petring_admin:set_blocked_words/1},
    {get, ["api", "admin", "notifications"], fun petring_admin:notifications/1},
    {get, ["api", "admin", "notifications", "ws"], fun petring_notifications_ws:upgrade/1},
    {delete, ["api", "admin", "notifications"], fun petring_admin:clear_notifications/1},

    {post, ["api", "admin", "newsletter"], fun petring_newsletter:create/1},
    {patch, ["api", "admin", "newsletter", ":id"], fun petring_newsletter:update/1},
    {delete, ["api", "admin", "newsletter", ":id"], fun petring_newsletter:delete/1},

    {get, ["api", "admin", "webhooks"], fun petring_admin:list_webhooks/1},
    {post, ["api", "admin", "webhooks"], fun petring_admin:create_webhook/1},
    {patch, ["api", "admin", "webhooks", ":id"], fun petring_admin:update_webhook/1},
    {delete, ["api", "admin", "webhooks", ":id"], fun petring_admin:delete_webhook/1},
    {post, ["api", "admin", "webhooks", ":id", "test"], fun petring_admin:test_webhook/1},

    {get, ["api", ":path*"], fun petring_public:api_not_found/1}
  ].
