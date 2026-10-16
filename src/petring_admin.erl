-module (petring_admin).
-export ([
  unverified_users/1, unverified_ads/1,
  verify_user/1, verify_ad/1,
  delete_user/1, delete_ad/1,
  get_blocked_words/1, set_blocked_words/1,
  notifications/1, clear_notifications/1, read_notifications/1,
  list_webhooks/1, events/1, create_webhook/1, 
  update_webhook/1, delete_webhook/1,
  test_webhook/1, all_users/1, all_ads/1,
  create_user/1, update_user/1,
  regenerate_token/1, create_ad/1, update_ad/1
]).

-spec unverified_users(Req :: errm_http:request()) -> {ok, errm_http:response()}.
unverified_users(_Req) ->
  case query("SELECT * FROM users WHERE verified = 0 ORDER BY created_at DESC", []) of
    {ok, Rows} -> petring_respond:ok(#{<<"users">> => [petring_format:format_user(R) || R <- Rows]}, [<<"users">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec unverified_ads(Req :: errm_http:request()) -> {ok, errm_http:response()}.
unverified_ads(_Req) ->
  case query("SELECT * FROM ads WHERE verified = 0 ORDER BY created_at DESC", []) of
    {ok, Rows} -> petring_respond:ok(#{<<"ads">> => [petring_format:format_ad(R) || R <- Rows]}, [<<"ads">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec verify_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
verify_user(Req) ->
  Name = name_param(Req),
  case exec("UPDATE users SET verified = 1, verified_at = ? WHERE username = ?", [now_secs(), Name]) of
    {ok, Changes} when Changes > 0 -> user_response(Name);
    {ok, _} -> petring_respond:error(404, <<"User not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec verify_ad(Req :: errm_http:request()) -> {ok, errm_http:response()}.
verify_ad(Req) ->
  Name = name_param(Req),
  case exec("UPDATE ads SET verified = 1, verified_at = ? WHERE username = ?", [now_secs(), Name]) of
    {ok, Changes} when Changes > 0 -> ad_response(Name);
    {ok, _} -> petring_respond:error(404, <<"Ad not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec delete_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
delete_user(Req) ->
  Name = name_param(Req),
  case exec("DELETE FROM users WHERE username = ?", [Name]) of
    {ok, Changes} when Changes > 0 -> petring_respond:ok(#{<<"message">> => <<"User deleted">>}, [<<"message">>]);
    {ok, _} -> petring_respond:error(404, <<"User not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec delete_ad(Req :: errm_http:request()) -> {ok, errm_http:response()}.
delete_ad(Req) ->
  Name = name_param(Req),
  case exec("DELETE FROM ads WHERE username = ?", [Name]) of
    {ok, Changes} when Changes > 0 -> petring_respond:ok(#{<<"message">> => <<"Ad deleted">>}, [<<"message">>]);
    {ok, _} -> petring_respond:error(404, <<"Ad not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec get_blocked_words(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get_blocked_words(Req) ->
  blocked_words_response(scope_param(Req)).

-spec set_blocked_words(Req :: errm_http:request()) -> {ok, errm_http:response()}.
set_blocked_words(Req) ->
  Scope = scope_param(Req),
  case valid_scope(Scope) of
    false -> petring_respond:error(400, <<"Invalid scope">>);
    true ->
      case body_map(Req) of
        {ok, Body} -> upsert_blocked_words(Scope, Body);
        error -> petring_respond:error(400, <<"Invalid body">>)
      end
  end.

-spec notifications(Req :: errm_http:request()) -> {ok, errm_http:response()}.
notifications(_Req) ->
  petring_respond:ok(#{<<"notifications">> => petring_notifications:get_all()}, [<<"notifications">>]).

-spec clear_notifications(Req :: errm_http:request()) -> {ok, errm_http:response()}.
clear_notifications(_Req) ->
  petring_notifications:clear(),
  petring_respond:ok(#{<<"message">> => <<"Notifications cleared">>}, [<<"message">>]).

-spec read_notifications(Req :: errm_http:request()) -> {ok, errm_http:response()}.
read_notifications(Req) ->
  case body_map(Req) of
    {ok, Body} -> petring_notifications:mark_read(maps:get(<<"ids">>, Body, all));
    error -> petring_notifications:mark_read(all)
  end,
  petring_respond:ok(#{<<"message">> => <<"Marked read">>}, [<<"message">>]).

-spec list_webhooks(Req :: errm_http:request()) -> {ok, errm_http:response()}.
list_webhooks(_Req) ->
  case query("SELECT * FROM webhooks ORDER BY id", []) of
    {ok, Rows} -> petring_respond:ok(#{<<"webhooks">> => [petring_format:format_webhook(R) || R <- Rows]}, [<<"webhooks">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec events(Req :: errm_http:request()) -> {ok, errm_http:response()}.
events(_Req) ->
  Events = [<<"user.submit">>, <<"ad.submit">>, <<"*">>],
  petring_respond:ok(#{<<"events">> => Events}, [<<"events">>]).

-spec create_webhook(Req :: errm_http:request()) -> {ok, errm_http:response()}.
create_webhook(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid body">>);
    {ok, Body} ->
      Url = maps:get(<<"url">>, Body, <<>>),
      Format = maps:get(<<"format">>, Body, <<"generic">>),
      case {valid_webhook(Url, Format), resolve_events(Body, undefined)} of
      {true, {ok, Events}} -> insert_webhook(Url, Format, Events, petring_token:mint());
        _ -> petring_respond:error(400, <<"Invalid webhook">>)
      end
  end.

-spec update_webhook(Req :: errm_http:request()) -> {ok, errm_http:response()}.
update_webhook(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid body">>);
    {ok, Body} -> do_update_webhook(id_param(Req), Body)
  end.

-spec delete_webhook(Req :: errm_http:request()) -> {ok, errm_http:response()}.
delete_webhook(Req) ->
  case id_param(Req) of
    undefined -> petring_respond:error(404, <<"Webhook not found">>);
    Id ->
      case exec("DELETE FROM webhooks WHERE id = ?", [Id]) of
        {ok, Changes} when Changes > 0 -> petring_respond:ok(#{<<"message">> => <<"Webhook deleted">>}, [<<"message">>]);
        {ok, _} -> petring_respond:error(404, <<"Webhook not found">>);
        error -> petring_respond:error(500, <<"Database error">>)
      end
  end.

-spec test_webhook(Req :: errm_http:request()) -> {ok, errm_http:response()}.
test_webhook(Req) ->
  case id_param(Req) of
    undefined -> petring_respond:error(404, <<"Webhook not found">>);
    Id ->
      case webhook_row(Id) of
        {ok, Row} -> webhook_test_response(petring_webhooks:deliver(Row, <<"test.test">>, test_payload()));
        error -> petring_respond:error(404, <<"Webhook not found">>)
      end
  end.

do_update_webhook(undefined, _Body) ->
  petring_respond:error(404, <<"Webhook not found">>);
do_update_webhook(Id, Body) ->
  case webhook_row(Id) of
    error -> petring_respond:error(404, <<"Webhook not found">>);
    {ok, Row} ->
      Url = maps:get(<<"url">>, Body, maps:get("url", Row, <<>>)),
      Format = maps:get(<<"format">>, Body, maps:get("format", Row, <<"generic">>)),
      Enabled = case maps:get(<<"enabled">>, Body, undefined) of
                  undefined -> maps:get("enabled", Row, 1);
                  Flag -> bool_to_int(Flag)
                end,
      case {valid_webhook(Url, Format), resolve_events(Body, Row)} of
        {true, {ok, Events}} ->
          case exec("UPDATE webhooks SET url = ?, format = ?, events = ?, enabled = ?, updated_at = ? WHERE id = ?",
                    [Url, Format, Events, Enabled, now_secs(), Id]) of
            {ok, _} -> webhook_response(Id);
            error -> petring_respond:error(500, <<"Database error">>)
          end;
        _ -> petring_respond:error(400, <<"Invalid webhook">>)
      end
  end.

insert_webhook(Url, Format, Events, Secret) ->
  case exec("INSERT INTO webhooks (url, format, events, secret, enabled, created_at) VALUES (?, ?, ?, ?, 1, ?)",
            [Url, Format, Events, Secret, now_secs()]) of
    {ok, _} ->
      case query("SELECT * FROM webhooks ORDER BY id DESC LIMIT 1", []) of
        {ok, [Row | _]} -> petring_respond:ok(petring_format:format_webhook(Row), webhook_order());
        _ -> petring_respond:error(500, <<"Database error">>)
      end;
    error -> petring_respond:error(500, <<"Database error">>)
  end.

webhook_row(Id) ->
  case query("SELECT * FROM webhooks WHERE id = ? LIMIT 1", [Id]) of
    {ok, [Row | _]} -> {ok, Row};
    _ -> error
  end.

webhook_response(Id) ->
  case webhook_row(Id) of
    {ok, Row} -> petring_respond:ok(petring_format:format_webhook(Row), webhook_order());
    error -> petring_respond:error(404, <<"Webhook not found">>)
  end.

webhook_test_response({ok, {{_, Status, _}, _, _}}) when Status >= 200, Status < 300 ->
  petring_respond:ok(#{<<"status">> => <<"delivered">>, <<"code">> => Status}, [<<"status">>, <<"code">>]);
webhook_test_response({ok, {{_, Status, _}, _, _}}) ->
  petring_respond:ok(#{<<"status">> => <<"failed">>, <<"code">> => Status}, [<<"status">>, <<"code">>]);
webhook_test_response(Other) ->
  Detail = iolist_to_binary(io_lib:format("~p", [Other])),
  petring_respond:ok(#{<<"status">> => <<"error">>, <<"detail">> => Detail}, [<<"status">>, <<"detail">>]).

resolve_events(Body, undefined) ->
  resolve_event_list(maps:get(<<"events">>, Body, [<<"*">>]));
resolve_events(Body, Row) ->
  case maps:get(<<"events">>, Body, undefined) of
    undefined -> {ok, maps:get("events", Row, <<"[\"*\"]">>)};
    Events -> resolve_event_list(Events)
  end.

resolve_event_list(Events) when is_list(Events) ->
  case lists:all(fun is_binary/1, Events) of
    true -> {ok, errm_json:to_binary(Events)};
    false -> error
  end;
resolve_event_list(_) -> error.

valid_webhook(Url, Format) ->
  valid_url(Url) andalso valid_format(Format).

-spec all_users(Req :: errm_http:request()) -> {ok, errm_http:response()}.
all_users(Req) ->
  {Limit, Offset} = page_params(Req),
  {Where, Args} = user_search(query_param(Req, <<"q">>)),
  case query("SELECT * FROM users " ++ Where ++ " ORDER BY id LIMIT ? OFFSET ?", Args ++ [Limit, Offset]) of
    {ok, Rows} ->
      case scalar("SELECT COUNT(*) FROM users " ++ Where, Args) of
        {ok, Total} -> petring_respond:ok(#{<<"users">> => petring_format:format_users(Rows), <<"total">> => Total}, [<<"users">>, <<"total">>]);
        error -> petring_respond:error(500, <<"Database error">>)
      end;
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec all_ads(Req :: errm_http:request()) -> {ok, errm_http:response()}.
all_ads(Req) ->
  {Limit, Offset} = page_params(Req),
  {Where, Args} = ad_search(query_param(Req, <<"q">>)),
  case query("SELECT * FROM ads " ++ Where ++ " ORDER BY id LIMIT ? OFFSET ?", Args ++ [Limit, Offset]) of
    {ok, Rows} ->
      case scalar("SELECT COUNT(*) FROM ads " ++ Where, Args) of
        {ok, Total} -> petring_respond:ok(#{<<"ads">> => petring_format:format_ads(Rows), <<"total">> => Total}, [<<"ads">>, <<"total">>]);
        error -> petring_respond:error(500, <<"Database error">>)
      end;
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec create_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
create_user(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid JSON body">>);
    {ok, Body} ->
      Username = maps:get(<<"username">>, Body, <<>>),
      Url = maps:get(<<"url">>, Body, <<>>),
      Contact = maps:get(<<"contact">>, Body, <<>>),
      Verified = bool_to_int(maps:get(<<"verified">>, Body, false)),
      do_create_user(Username, Url, Contact, Verified)
  end.

do_create_user(<<>>, _, _, _) -> petring_respond:error(400, <<"Invalid username">>);
do_create_user(_, <<>>, _, _) -> petring_respond:error(400, <<"Invalid url">>);
do_create_user(Username, Url, Contact, Verified) ->
  case petring_filter:url_allowed(<<"user_url">>, Url) of
    false -> petring_respond:error(400, <<"Invalid url">>);
    true -> insert_user(Username, Url, Contact, Verified)
  end.


insert_user(Username, Url, Contact, Verified) ->
  Token = petring_token:mint(),
  Now = now_secs(),
  case exec("INSERT INTO users (username, url, contact, manage_token_hash, manage_token_created_at, verified, verified_at, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [Username, Url, Contact, petring_token:hash(Token), Now, Verified, verified_at(Verified), Now]) of
    {ok, _} ->
      case query("SELECT * FROM users WHERE username = ? LIMIT 1", [Username]) of
        {ok, [Row | _]} ->
          petring_respond:ok(#{<<"user">> => petring_format:format_user(Row), <<"manage_token">> => Token},
                             [<<"user">>, <<"manage_token">>]);
        _ -> petring_respond:error(500, <<"Database error">>)
      end;
    error -> petring_respond:error(409, <<"User or url already exists">>)
  end.

-spec update_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
update_user(Req) ->
  Name = name_param(Req),
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid JSON body">>);
    {ok, Body} ->
      case query("SELECT * FROM users WHERE username = ? LIMIT 1", [Name]) of
        {ok, [Row | _]} ->
          NewUrl = maps:get(<<"url">>, Body, maps:get("url", Row, <<>>)),
          NewContact = maps:get(<<"contact">>, Body, maps:get("contact", Row, <<>>)),
          case petring_filter:url_allowed(<<"user_url">>, NewUrl) of
            false -> petring_respond:error(400, <<"Invalid url">>);
            true -> do_update_user(Name, NewUrl, NewContact)
          end;
        _ -> petring_respond:error(404, <<"User not found">>)
      end
  end.

do_update_user(Name, NewUrl, NewContact) ->
  case exec("UPDATE users SET url = ?, contact = ?, edited_at = ? WHERE username = ?",
            [NewUrl, NewContact, now_secs(), Name]) of
    {ok, _} ->
      _ = exec("UPDATE ads SET ad_url = ? WHERE username = ?", [NewUrl, Name]),
      user_response(Name);
    error -> petring_respond:error(409, <<"Url already exists">>)
  end.

-spec regenerate_token(Req :: errm_http:request()) -> {ok, errm_http:response()}.
regenerate_token(Req) ->
  Name = name_param(Req),
  Token = petring_token:mint(),
  Now = now_secs(),
  case exec("UPDATE users SET manage_token_hash = ?, manage_token_created_at = ?, manage_token_last_used_at = NULL, edited_at = ? WHERE username = ?",
            [petring_token:hash(Token), Now, Now, Name]) of
    {ok, Changes} when Changes > 0 ->
      petring_respond:ok(#{<<"manage_token">> => Token}, [<<"manage_token">>]);
    {ok, _} -> petring_respond:error(404, <<"User not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec create_ad(Req :: errm_http:request()) -> {ok, errm_http:response()}.
create_ad(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid JSON body">>);
    {ok, Body} ->
      Name = maps:get(<<"username">>, Body, <<>>),
      ImageUrl = maps:get(<<"image_url">>, Body, <<>>),
      case Name =/= <<>> andalso ImageUrl =/= <<>> andalso petring_filter:url_allowed(<<"ad_url">>, ImageUrl) of
        false -> petring_respond:error(400, <<"Invalid image url">>);
        true -> insert_admin_ad(Name, ImageUrl)
      end
  end.

insert_admin_ad(Name, ImageUrl) ->
  case query("SELECT url FROM users WHERE username = ? LIMIT 1", [Name]) of
    {ok, [Row | _]} ->
      AdUrl = maps:get("url", Row, <<>>),
      case exec("INSERT INTO ads (username, image_url, ad_url, verified, verified_at, created_at) "
                "VALUES (?, ?, ?, 1, ?, ?)",
                [Name, ImageUrl, AdUrl, now_secs(), now_secs()]) of
        {ok, _} -> ad_response(Name);
        error -> petring_respond:error(409, <<"Ad already exists">>)
      end;
    _ -> petring_respond:error(404, <<"User not found">>)
  end.

-spec update_ad(Req :: errm_http:request()) -> {ok, errm_http:response()}.
update_ad(Req) ->
  Name = name_param(Req),
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid JSON body">>);
    {ok, Body} ->
      case query("SELECT * FROM ads WHERE username = ? LIMIT 1", [Name]) of
        {ok, [Row | _]} ->
          NewImage = maps:get(<<"image_url">>, Body, maps:get("image_url", Row, <<>>)),
          NewAdUrl = maps:get(<<"ad_url">>, Body, maps:get("ad_url", Row, <<>>)),
          case petring_filter:url_allowed(<<"ad_url">>, NewImage) andalso petring_filter:url_allowed(<<"ad_url">>, NewAdUrl) of
            false -> petring_respond:error(400, <<"Invalid url">>);
            true -> do_update_ad(Name, NewImage, NewAdUrl)
          end;
        _ -> petring_respond:error(404, <<"Ad not found">>)
      end
  end.

do_update_ad(Name, NewImage, NewAdUrl) ->
  case exec("UPDATE ads SET image_url = ?, ad_url = ?, edited_at = ? WHERE username = ?",
            [NewImage, NewAdUrl, now_secs(), Name]) of
    {ok, _} -> ad_response(Name);
    error -> petring_respond:error(409, <<"Ad url already exists">>)
  end.

verified_at(1) -> now_secs();
verified_at(_) -> null.

valid_url(Url) when is_binary(Url) ->
  binary:match(Url, <<"https://">>) =:= {0, 8} orelse binary:match(Url, <<"http://">>) =:= {0, 7};
valid_url(_) -> false.

valid_format(<<"generic">>) -> true;
valid_format(<<"discord">>) -> true;
valid_format(<<"slack">>) -> true;
valid_format(_) -> false.

bool_to_int(true) -> 1;
bool_to_int(false) -> 0;
bool_to_int(1) -> 1;
bool_to_int(0) -> 0;
bool_to_int(_) -> 1.

id_param(Req) ->
  case maps:get(<<"id">>, maps:get(params, Req, #{}), undefined) of
    undefined -> undefined;
    Bin -> try binary_to_integer(Bin) catch _:_ -> undefined end
  end.

test_payload() ->
  #{
    <<"event">> => <<"notification">>,
    <<"kind">> => <<"test">>,
    <<"action">> => <<"test">>,
    <<"username">> => <<"petring">>,
    <<"content">> => <<"This is a test notification">>,
    <<"ref_id">> => <<>>,
    <<"target">> => <<>>,
    <<"created_at">> => now_secs()
  }.

webhook_order() -> [<<"id">>, <<"url">>, <<"format">>, <<"events">>, <<"enabled">>, <<"created_at">>, <<"updated_at">>, <<"secret">>, <<"last_status">>, <<"last_error">>, <<"last_delivered_at">>].

user_response(Name) ->
  case query("SELECT * FROM users WHERE username = ?", [Name]) of
    {ok, [Row | _]} -> petring_respond:ok(petring_format:format_user(Row), user_order());
    _ -> petring_respond:error(404, <<"User not found">>)
  end.

ad_response(Name) ->
  case query("SELECT * FROM ads WHERE username = ?", [Name]) of
    {ok, [Row | _]} -> petring_respond:ok(petring_format:format_ad(Row), ad_order());
    _ -> petring_respond:error(404, <<"Ad not found">>)
  end.

blocked_words_response(Scope) ->
  case query("SELECT * FROM blocked_words WHERE scope = ?", [Scope]) of
    {ok, [Row | _]} -> petring_respond:ok(petring_format:format_blocked_word(Row), blocked_order());
    {ok, []} -> petring_respond:error(404, <<"Blocked words not found">>);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

upsert_blocked_words(Scope, Body) ->
  case query("SELECT keywords, patterns FROM blocked_words WHERE scope = ?", [Scope]) of
    {ok, Existing} ->
      Old = case Existing of [Row | _] -> Row; [] -> #{} end,
      Keywords = provided(Body, <<"keywords">>, maps:get("keywords", Old, <<"[]">>)),
      Patterns = provided(Body, <<"patterns">>, maps:get("patterns", Old, <<"[]">>)),
      Sql = "INSERT INTO blocked_words (scope, enforced_by, keywords, patterns, updated_at) "
            "VALUES (?, 'admin', ?, ?, ?) "
            "ON CONFLICT(scope) DO UPDATE SET keywords = excluded.keywords, "
            "patterns = excluded.patterns, updated_at = excluded.updated_at",
      case exec(Sql, [Scope, Keywords, Patterns, now_secs()]) of
        {ok, _} -> blocked_words_response(Scope);
        error -> petring_respond:error(500, <<"Database error">>)
      end;
    error -> petring_respond:error(500, <<"Database error">>)
  end.

provided(Body, Key, Default) ->
  case maps:get(Key, Body, undefined) of
    undefined -> Default;
    Value -> errm_json:to_binary(Value)
  end.

valid_scope(<<"user_url">>) -> true;
valid_scope(<<"ad_url">>) -> true;
valid_scope(<<"global">>) -> true;
valid_scope(_) -> false.

name_param(Req) -> maps:get(<<"name">>, maps:get(params, Req, #{}), <<>>).
scope_param(Req) -> maps:get(<<"scope">>, maps:get(params, Req, #{}), <<>>).

query_param(Req, Key) -> maps:get(Key, maps:get(query, Req, #{}), <<>>).

page_params(Req) ->
  {clamp(int_query(Req, <<"limit">>, 50), 1, 500), max(0, int_query(Req, <<"offset">>, 0))}.

clamp(N, Lo, Hi) -> max(Lo, min(Hi, N)).

int_query(Req, Key, Default) ->
  case query_param(Req, Key) of
    <<>> -> Default;
    Bin -> try binary_to_integer(Bin) catch _:_ -> Default end
  end.

user_search(<<>>) -> {"", []};
user_search(Q) ->
  Like = <<"%", Q/binary, "%">>,
  {"WHERE username LIKE ? OR url LIKE ?", [Like, Like]}.

ad_search(<<>>) -> {"", []};
ad_search(Q) ->
  Like = <<"%", Q/binary, "%">>,
  {"WHERE username LIKE ? OR image_url LIKE ? OR ad_url LIKE ?", [Like, Like, Like]}.

body_map(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Map} when is_map(Map) -> {ok, Map};
    _ -> error
  end.

query(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db, Sql, Args) of
        {ok, Rows} -> {ok, Rows};
        _ -> error
      catch _:_ -> error
      end;
    {error, _} -> error
  end.

scalar(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:scalar(Db, Sql, Args) of
        {ok, Value} -> {ok, Value};
        _ -> error
      catch _:_ -> error
      end;
    {error, _} -> error
  end.

exec(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db, Sql, Args) of
        {ok, Changes} -> {ok, Changes};
        _ -> error
      catch _:_ -> error
      end;
    {error, _} -> error
  end.

now_secs() -> erlang:system_time(second).

user_order() -> [<<"id">>, <<"username">>, <<"url">>, <<"contact">>, <<"verified">>, <<"created_at">>, <<"edited_at">>, <<"verified_at">>, <<"manage_token_created_at">>, <<"manage_token_last_used_at">>].
ad_order() -> [<<"id">>, <<"username">>, <<"image_url">>, <<"ad_url">>, <<"verified">>, <<"created_at">>, <<"edited_at">>, <<"verified_at">>].
blocked_order() -> [<<"scope">>, <<"enforced_by">>, <<"keywords">>, <<"patterns">>, <<"updated_at">>].
