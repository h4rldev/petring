-module (petring_visits).
-export ([middleware/0, stats/0]).

-spec middleware() -> errm_http:middleware().
middleware() ->
  fun(Req, Next) ->
    case is_page_view(Req) of
      true -> record(petring_ip:client_ip(Req));
      false -> ok
    end,
    Next(Req)
  end.

is_page_view(Req) ->
  maps:get(method, Req, get) =:= get
    andalso not is_api(maps:get(raw_path, Req, <<"/">>))
    andalso accepts_html(Req).

is_api(Path) when is_binary(Path) -> binary:match(Path, <<"/api">>) =:= {0, 4};
is_api(_) -> false.

accepts_html(Req) ->
  Headers = maps:get(headers, Req, #{}),
  case maps:get(<<"accept">>, Headers, <<>>) of
    Accept when is_binary(Accept) ->
      binary:match(Accept, <<"text/html">>) =/= nomatch;
    _ -> false
  end.

-spec record(Ip :: binary()) -> ok.
record(Ip) ->
  Now = erlang:system_time(second),
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db,
        "INSERT INTO visits (ip, hits, first_seen, last_seen) VALUES (?, 1, ?, ?) "
        "ON CONFLICT(ip) DO UPDATE SET hits = hits + 1, last_seen = excluded.last_seen",
        [Ip, Now, Now]) of
          {ok, _} -> ok
      catch _:_ -> ok
      end;
    {error, _} -> ok
  end.

-spec stats() -> map().
stats() ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
        "SELECT "
        "(SELECT COUNT(*) FROM users WHERE verified = 1) AS members, "
        "(SELECT COUNT(*) FROM ads) AS ads, "
        "(SELECT COALESCE(SUM(hits), 0) FROM visits) AS visits, "
        "(SELECT COUNT(*) FROM visits) AS unique_visits",
        []) of
        {ok, [Row]} -> stats_map(Row);
        _ -> stats_map(#{})
      catch _:_ -> stats_map(#{})
      end;
    {error, _} -> stats_map(#{})
  end.

stats_map(Row) ->
  #{
    <<"members">> => maps:get("members", Row, 0),
    <<"ads">> => maps:get("ads", Row, 0),
    <<"visits">> => maps:get("visits", Row, 0),
    <<"unique_visits">> => maps:get("unique_visits", Row, 0)
  }.
