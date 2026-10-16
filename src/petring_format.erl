-module (petring_format).
-export ([format_public_user/1, format_public_ad/1]).
-export ([format_user/1, format_ad/1, format_account/1, format_notification/1, format_blocked_word/1, format_webhook/1, format_newsletter/1]).
-export ([format_users/1, format_ads/1]).


-spec format_public_user(Row :: map()) -> Formatted :: map().
format_public_user(Row) ->
  #{
    <<"username">> => maps:get("username", Row, null),
    <<"url">> => maps:get("url", Row, null)
  }.

-spec format_public_ad(Row :: map())-> Formatted :: map().
format_public_ad(Row) ->
  #{
    <<"username">> => maps:get("username", Row, null),
    <<"image_url">> => maps:get("image_url", Row, null),
    <<"ad_url">> => maps:get("ad_url", Row, null)
  }.

-spec format_user(Row :: map()) -> Formatted :: map().
format_user(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"username">> => maps:get("username", Row, null),
    <<"url">> => maps:get("url", Row, null),
    <<"contact">> => maps:get("contact", Row, null),
    <<"verified">> => to_bool(maps:get("verified", Row, 0)),
    <<"created_at">> => maps:get("created_at", Row, null),
    <<"edited_at">> => maps:get("edited_at", Row, null),
    <<"verified_at">> => maps:get("verified_at", Row, null),
    <<"manage_token_created_at">> => maps:get("manage_token_created_at", Row, null),
    <<"manage_token_last_used_at">> => maps:get("manage_token_last_used_at", Row, null)
  }.

-spec format_ad(Row :: map()) -> Formatted :: map().
format_ad(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"username">> => maps:get("username", Row, null),
    <<"image_url">> => maps:get("image_url", Row, null),
    <<"ad_url">> => maps:get("ad_url", Row, null),
    <<"verified">> => to_bool(maps:get("verified", Row, 0)),
    <<"created_at">> => maps:get("created_at", Row, null),
    <<"edited_at">> => maps:get("edited_at", Row, null),
    <<"verified_at">> => maps:get("verified_at", Row, null)
  }.

-spec format_account(Row :: map()) -> Formatted :: map().
format_account(Row) ->
  #{
    <<"username">> => maps:get("username", Row, null),
    <<"role">> => maps:get("role", Row, null),
    <<"auth_version">> => maps:get("auth_version", Row, null),
    <<"created_at">> => maps:get("created_at", Row, null),
    <<"updated_at">> => maps:get("updated_at", Row, null)
  }.

-spec format_notification(Row :: map()) -> Formatted :: map().
format_notification(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"kind">> => maps:get("kind", Row, null),
    <<"action">> => maps:get("action", Row, null),
    <<"username">> => maps:get("username", Row, null),
    <<"content">> => maps:get("content", Row, null),
    <<"ref_id">> => maps:get("ref_id", Row, null),
    <<"target">> => maps:get("target", Row, null),
    <<"created_at">> => maps:get("created_at", Row, null),
    <<"read">> => to_bool(maps:get("read", Row, 0))
   }.

-spec format_blocked_word(Row :: map()) -> Formatted :: map().
format_blocked_word(Row) ->
  #{
    <<"scope">> => maps:get("scope", Row, null),
    <<"enforced_by">> => maps:get("enforced_by", Row, null),
    <<"keywords">> => decode_array(maps:get("keywords", Row, <<"[]">>)),
    <<"patterns">> => decode_array(maps:get("patterns", Row, <<"[]">>)),
    <<"updated_at">> => maps:get("updated_at", Row, null)
  }.

-spec format_webhook(Row :: map()) -> Formatted :: map().
format_webhook(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"url">> => maps:get("url", Row, null),
    <<"format">> => maps:get("format", Row, null),
    <<"events">> => decode_array(maps:get("events", Row, <<"[]">>)),
    <<"enabled">> => to_bool(maps:get("enabled", Row, 0)),
    <<"created_at">> => maps:get("created_at", Row, null),
    <<"updated_at">> => maps:get("updated_at", Row, null),
    <<"secret">> => maps:get("secret", Row, null),
    <<"last_status">> => maps:get("last_status", Row, null),
    <<"last_error">> => maps:get("last_error", Row, null),
    <<"last_delivered_at">> => maps:get("last_delivered_at", Row, null)
  }.

-spec format_newsletter(Row :: map()) -> Formatted :: map().
format_newsletter(Row) ->
  #{
    <<"id">> => maps:get("id", Row, null),
    <<"slug">> => maps:get("slug", Row, null),
    <<"title">> => maps:get("title", Row, null),
    <<"content_markdown">> => maps:get("content_markdown", Row, null),
    <<"status">> => maps:get("status", Row, <<"published">>),
    <<"authors">> => decode_array(maps:get("authors", Row, <<"[]">>)),
    <<"posted_at">> => maps:get("posted_at", Row, null),
    <<"edited_at">> => maps:get("edited_at", Row, null)
  }.

-spec format_users([map()]) -> [map()].
format_users(Rows) -> [format_user(R) || R <- Rows].

-spec format_ads([map()]) -> [map()].
format_ads(Rows) -> [format_ad(R) || R <- Rows].

to_bool(1) -> true;
to_bool(true) -> true; 
to_bool(_) -> false.

decode_array(Raw) ->
  case errm_json:decode(Raw) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.
