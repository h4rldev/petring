-module (petring_public).
-export ([index/1, server_info/1, uptime/1, api_not_found/1,
         get_users/1, random_user/1, random_ad/1,
         get_user/1, user_next/1, user_prev/1, user_random/1]).

-spec index(Req :: errm_http:request()) -> {ok, errm_http:response()}.
index(_Req) ->
  petring_respond:html(index_html()).

index_html() ->
  <<"<!DOCTYPE html>\n"
    "<html lang=\"en\"><head><meta charset=\"utf-8\"><title>petRing API</title></head>\n"
    "<body><h1>petRing API</h1>\n"
    "<h2>Webring</h2><ul>\n"
    "<li><a href=\"/api/server-info\">/api/server-info</a> - server metadata: name, version, author, license, source and uptime.</li>\n"
    "<li><a href=\"/api/uptime\">/api/uptime</a> - application and system uptime.</li>\n"
    "<li><a href=\"/api/users\">/api/users</a> - every verified member as username and url.</li>\n"
    "<li><a href=\"/api/users/random\">/api/users/random</a> - 307 redirect to a random verified member.</li>\n"
    "<li><a href=\"/api/random-ad\">/api/random-ad</a> - a random verified ad: username, image_url, ad_url.</li>\n"
    "<li><a href=\"/api/user/{username}\">/api/user/{username}</a> - 307 redirect to that member's site.</li>\n"
    "<li><a href=\"/api/user/{username}/next\">/api/user/{username}/next</a> - 307 redirect to the next member in the ring.</li>\n"
    "<li><a href=\"/api/user/{username}/prev\">/api/user/{username}/prev</a> - 307 redirect to the previous member.</li>\n"
    "<li><a href=\"/api/user/{username}/random\">/api/user/{username}/random</a> - 307 redirect to a per-user seeded random member.</li>\n"
    "</ul>\n"
    "<h2>Newsletter</h2><ul>\n"
    "<li><a href=\"/api/newsletter\">/api/newsletter</a> - all posts (id, slug, title, content_markdown, posted_at, edited_at), newest first.</li>\n"
    "<li><a href=\"/api/newsletter/{id}\">/api/newsletter/{id}</a> - a single post by id or slug.</li>\n"
    "<li><a href=\"/newsletter/feed.xml\">/newsletter/feed.xml</a> - RSS 2.0 feed with each post's markdown rendered to HTML.</li>\n"
    "<li>\"/api/newsletter/ws\" - WebSocket streaming post created/updated/deleted events.</li>\n"
    "</ul>\n"
    "</body></html>\n">>.

-spec server_info(Req :: errm_http:request()) -> {ok, errm_http:response()}.
server_info(_Req) ->
  petring_respond:ok(#{
    <<"name">> => <<"petRing">>,
    <<"version">> => <<"0.1.0">>,
    <<"description">> => <<"A pet-coded webring :3">>,
    <<"authors">> => [<<"h4rl">>],
    <<"license">> => <<"BSD 3-Clause License">>,
    <<"source">> => <<"https://github.com/h4rldev/petring">>,
    <<"server_uptime">> => petring_uptime:format_duration(petring_uptime:app_uptime()),
    <<"system_uptime">> => petring_uptime:format_duration(petring_uptime:system_uptime())
  }, [<<"name">>, <<"version">>, <<"description">>, <<"authors">>, <<"license">>,
      <<"source">>, <<"server_uptime">>, <<"system_uptime">>]).

-spec uptime(Req :: errm_http:request()) -> {ok, errm_http:response()}.
uptime(_Req) ->
  petring_respond:ok(#{
    <<"app_uptime">> => petring_uptime:format_duration(petring_uptime:app_uptime()),
    <<"system_uptime">> => petring_uptime:format_duration(petring_uptime:system_uptime())
  }, [<<"app_uptime">>, <<"system_uptime">>]).

-spec api_not_found(Req :: errm_http:request()) -> {ok, errm_http:response()}.
api_not_found(Req) ->
  Path = maps:get(raw_path, Req, <<"/api">>),
  petring_respond:error(404, <<"The requested resource at ", Path/binary, " could not be found.">>).

-spec get_users(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get_users(_Req) ->
  case query("SELECT username, url FROM users WHERE verified = 1 ORDER BY id ASC", []) of
    {ok, Rows} ->
      petring_respond:ok(
        #{<<"users">> => [petring_format:format_public_user(R) || R <- Rows]},
        [<<"users">>]);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec random_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
random_user(_Req) ->
  case row("SELECT url FROM users WHERE verified = 1 ORDER BY RANDOM() LIMIT 1", []) of
    {ok, R} ->
      petring_respond:redirect(maps:get("url", R));
    empty ->
      petring_respond:error(404, <<"Couldn't pick a random user">>);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec random_ad(Req :: errm_http:request()) -> {ok, errm_http:response()}.
random_ad(_Req) ->
  case row("SELECT username, image_url, ad_url FROM ads WHERE verified = 1 ORDER BY RANDOM() LIMIT 1", []) of
    {ok, R} ->
      petring_respond:ok(petring_format:format_public_ad(R),
        [<<"username">>, <<"image_url">>, <<"ad_url">>]);
    empty ->
      petring_respond:error(404, <<"Couldn't pick a random ad">>);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec get_user(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get_user(Req) ->
  case name_param(Req) of
    <<"{username}">> ->
      petring_respond:ok(
        #{<<"message">> => <<"Hey, you followed the API reference, but {username} leads nowhere!">>},
        [<<"message">>]);
    Name ->
      case url_of("SELECT url FROM users WHERE username = ? LIMIT 1", [Name]) of
        {ok, Url} ->
          petring_respond:redirect(Url);
        empty ->
          petring_respond:error(404, <<"User not found">>);
        error ->
          petring_respond:error(500, <<"Database error">>)
      end
  end.

-spec user_next(Req :: errm_http:request()) -> {ok, errm_http:response()}.
user_next(Req) ->
  case row("SELECT id FROM users WHERE username = ? LIMIT 1", [name_param(Req)]) of
    {ok, R} ->
      wrap_redirect(
        "SELECT url FROM users WHERE id > ? ORDER BY id ASC LIMIT 1",
        "SELECT url FROM users ORDER BY id ASC LIMIT 1",
        maps:get("id", R));
    empty ->
      petring_respond:error(404, <<"User not found">>);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec user_prev(Req :: errm_http:request()) -> {ok, errm_http:response()}.
user_prev(Req) ->
  case row("SELECT id FROM users WHERE username = ? AND verified = 1 LIMIT 1", [name_param(Req)]) of
    {ok, R} ->
      wrap_redirect(
        "SELECT url FROM users WHERE verified = 1 AND id < ? ORDER BY id DESC LIMIT 1",
        "SELECT url FROM users WHERE verified = 1 ORDER BY id DESC LIMIT 1",
        maps:get("id", R));
    empty ->
      petring_respond:error(404, <<"User not found">>);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec user_random(Req :: errm_http:request()) -> {ok, errm_http:response()}.
user_random(Req) ->
  case row("SELECT id FROM users WHERE username = ? AND verified = 1 LIMIT 1", [name_param(Req)]) of
    {ok, R} ->
      random_verified_user(maps:get("id", R));
    empty ->
      petring_respond:error(404, <<"User not found">>);
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

random_verified_user(Id) ->
  case query("SELECT url FROM users WHERE verified = 1 ORDER BY id ASC", []) of
    {ok, Rows} when Rows =/= [] ->
      rand:seed_s(exsss, {Id, Id, Id}),
      Picked = lists:nth(rand:uniform(length(Rows)), Rows),
      petring_respond:redirect(maps:get("url", Picked));
    _ ->
      petring_respond:error(404, <<"Couldn't pick a random user">>)
  end.

wrap_redirect(SpecificSql, WrapSql, Id) ->
  case url_of(SpecificSql, [Id]) of
    {ok, Url} ->
      petring_respond:redirect(Url);
    empty ->
      case url_of(WrapSql, []) of
        {ok, Url} -> petring_respond:redirect(Url);
        _ -> petring_respond:error(404, <<"User not found">>)
      end;
    error ->
      petring_respond:error(500, <<"Database error">>)
  end.

query(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db, Sql, Args) of
        {ok, Rows} -> {ok, Rows};
        _ -> error
      catch _:_ -> error end;
    {error, _} ->
      error
  end.

row(Sql, Args) ->
  case query(Sql, Args) of
    {ok, [R | _]} -> {ok, R};
    {ok, []} -> empty;
    error -> error
  end.

url_of(Sql, Args) ->
  case row(Sql, Args) of
    {ok, R} -> {ok, maps:get("url", R)};
    Other -> Other
  end.

name_param(Req) ->
  maps:get(<<"name">>, maps:get(params, Req, #{}), <<>>).
