-module (petring_filter).
-export ([url_allowed/2, ensure_http_clients/0]).

-define (HEAD_TIMEOUT, 5000).

-spec url_allowed(Scope :: binary(), Url :: binary()) -> boolean().
url_allowed(Scope, Url) ->
  case host_of(Url) of
    {ok, Host} -> not blocked(Scope, Host) andalso reachable(Url);
    error -> false
  end.

host_of(Url) ->
  try uri_string:parse(normalize(Url)) of
    #{scheme := Scheme, host := Host} ->
      case {lower(Scheme), Host} of
        {<<"https">>, <<>>} -> error;
        {<<"https">>, Bin} -> {ok, Bin};
        _ -> error
      end;
    _ -> error
  catch _:_ -> error
  end.

normalize(Url) ->
  case binary:match(Url, <<"://">>) of
    nomatch -> <<"https://", Url/binary>>;
    _ -> Url
  end.

reachable(Url) ->
  case petring_config:get(url_reachability) of
    true -> head_ok(Url);
    _ -> true
  end.

head_ok(Url) ->
  case ensure_http_clients() of
    ok ->
      HttpOptions = [
        {timeout, ?HEAD_TIMEOUT},
        {connect_timeout, ?HEAD_TIMEOUT},
        {ssl, [{verify, verify_none}]}
      ],
      case httpc:request(head, {normalize(Url), []}, HttpOptions, [{body_format, binary}]) of
        {ok, {{_, Status, _}, _, _}} -> Status >= 200 andalso Status < 400;
        _ -> false
      end;
    error ->
      false
  end.

-spec ensure_http_clients() -> ok | error.
ensure_http_clients() ->
  case application:ensure_all_started(ssl) of
    {ok, _} ->
      case application:ensure_all_started(inets) of
        {ok, _} -> ok;
        _ -> error
      end;
    _ ->
      error
  end.

blocked(Scope, Host) ->
  case rows(Scope) of
    {ok, Rows} -> lists:any(fun(Row) -> matches(Row, Host) end, Rows);
    error -> true
  end.

rows(Scope) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT keywords, patterns FROM blocked_words WHERE scope = ? OR scope = 'global'",
            [Scope]) of
        {ok, Rows} -> {ok, Rows}
      catch _:_ -> error
      end;
    {error, _} -> error
  end.

matches(Row, Host) ->
  Keywords = decode_list(maps:get("keywords", Row, <<"[]">>)),
  Patterns = decode_list(maps:get("patterns", Row, <<"[]">>)),
  has_keyword(Keywords, Host) orelse has_pattern(Patterns, Host).

has_keyword(Keywords, Host) ->
  Lower = lower(Host),
  lists:any(fun(Keyword) ->
    Needle = lower(Keyword),
    Needle =/= <<>> andalso binary:match(Lower, Needle) =/= nomatch
  end, Keywords).

has_pattern(Patterns, Host) ->
  lists:any(fun(Pattern) ->
    case Pattern of
      <<>> -> false;
      Regex ->
        try re:run(Host, Regex, [{capture, none}, caseless]) of
          match -> true;
          _ -> false
        catch _:_ -> false
        end
    end
  end, Patterns).

decode_list(Raw) ->
  case errm_json:decode(Raw) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

lower(Value) ->
  string:lowercase(Value).
