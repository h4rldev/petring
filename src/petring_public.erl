-module (petring_public).
-export ([index/1, server_info/1, uptime/1, stats/1, api_not_found/1,
         get_users/1, get_ads/1, random_user/1, random_ad/1,
         get_user/1, user_next/1, user_prev/1, user_random/1, sitemap/1]).

-spec index(Req :: errm_http:request()) -> {ok, errm_http:response()}.
index(_Req) ->
  petring_respond:redirect(<<"/docs/">>).

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

-spec stats(Req :: errm_http:request()) -> {ok, errm_http:response()}.
stats(_Req) ->
  petring_respond:ok(petring_visits:stats(), [<<"members">>, <<"ads">>, <<"visits">>, <<"unique_visits">>]).
  

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

-spec get_ads(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get_ads(_Req) ->
  case query("SELECT username, image_url, ad_url FROM ads WHERE verified = 1 ORDER BY id ASC", []) of
    {ok, Rows} ->
      petring_respond:ok(
        #{<<"ads">> => [petring_format:format_public_ad(R) || R <- Rows]},
        [<<"ads">>]);
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
      case url_of("SELECT url FROM users WHERE username = ? AND verified = 1 LIMIT 1", [Name]) of
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
  case row("SELECT id FROM users WHERE username = ? AND verified = 1 LIMIT 1", [name_param(Req)]) of
    {ok, R} ->
      wrap_redirect(
        "SELECT url FROM users WHERE verified = 1 AND id > ? ORDER BY id ASC LIMIT 1",
        "SELECT url FROM users WHERE verified = 1 ORDER BY id ASC LIMIT 1",
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

-spec sitemap(Req :: errm_http:request()) -> {ok, errm_http:response()}.
sitemap(_Req) ->
  Site = petring_config:get(server_url),
  Body = iolist_to_binary([
    <<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n">>,
    <<"<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n">>,
    [url_tag([Site, P]) || P <- ["/", "/newsletter/", "/docs/", "/login/", "/privacy/"]],
    [url_tag([Site, "/newsletter/", slug_of(R), "/"]) || R <- newsletter_rows()],
    <<"</urlset>\n">>
  ]),
  {ok, {200, #{<<"content-type">> => <<"application/xml; charset=utf-8">>}, Body}}.

url_tag(Url) ->
  [<<"<url><loc>">>, xml_esc(iolist_to_binary(Url)), <<"</loc></url>\n">>].

newsletter_rows() ->
  case query("SELECT slug FROM newsletter ORDER BY posted_at DESC", []) of
    {ok, Rows} -> Rows;
    error -> []
  end.

slug_of(Row) ->
  case maps:get("slug", Row, <<>>) of
    B when is_binary(B) -> B;
    L when is_list(L) -> list_to_binary(L);
    _ -> <<>>
  end.

xml_esc(Bin) ->
  iolist_to_binary([xml_char(C) || <<C>> <= Bin]).

xml_char($&) -> <<"&amp;">>;
xml_char($<) -> <<"&lt;">>;
xml_char($>) -> <<"&gt;">>;
xml_char($") -> <<"&quot;">>;
xml_char($') -> <<"&apos;">>;
xml_char(C) -> <<C>>.
