-module (petring_middlewares).
-export ([get/0, auth_middleware/0, authenticate/1, get_claims/1, get_manage_user/1]).

get() ->
  Compression = #{preferred => [zstd, gzip], compression_level => 9, min_length => 256},
  Decompression = #{allowed => [gzip, zstd, deflate]},

  CORS = errm_http_cors:make(#{
    policies => [
      #{
        origin => cors_origin(),
        methods => [get, post, put, patch, delete, head],
        headers => ["Accept", "Content-Type", "Authorization", "X-Dry-Run"],
        credentials => petring_config:get(cors_credentials),
        max_age => 604800
      }
    ]
  }),

  [
    petring_access_log:middleware(),
    petring_visits:middleware(),
    errm_http_compress:compress(Compression),
    CORS,
    errm_http_cookie:with_cookies(),
    auth_middleware(),
    errm_http_compress:decompress(Decompression),
    petring_dry_run:middleware()
  ].

cors_origin() ->
  case petring_config:get(cors_origins) of
    [<<"*">>] -> <<"*">>;
    Origins -> Origins
  end.

-spec auth_middleware() -> errm_http:middleware().
auth_middleware() ->
  fun(Req, Next) ->
    Segments = to_segments(maps:get(path, Req, <<"/">>)),
    Method = maps:get(method, Req, get),
    case Segments of
      [<<"api">>, <<"admin">> | _] ->
        case {Method, Segments} of
          {post, [<<"api">>, <<"admin">>, <<"login">>]} -> Next(Req);
          _ -> admin_gate(Req, Next)
        end;
      [<<"api">>, <<"manage">> | _] ->
        manage_gate(Req, Next);
      _ ->
        Next(Req)
    end
  end.

admin_gate(Req, Next) ->
  case authenticate(Req) of
    {ok, Claims} -> Next(Req#{claims => Claims});
    {error, _} -> petring_respond:error(401, <<"Unauthorized">>)
  end.

manage_gate(Req, Next) ->
  case authenticate_manage(Req) of
    {ok, User} -> Next(Req#{manage_user => User});
    {error, _} -> petring_respond:error(401, <<"Unauthorized">>)
  end.

-spec authenticate(Req :: errm_http:request()) -> {ok, map()} | {error, term()}.
authenticate(Req) ->
  case petring_secrets:get_jwt_secret() of
    {ok, Secret} when is_binary(Secret) ->
      Jar = errm_http_cookie_jar:from_request(Req, undefined),
      case errm_http_cookie_jar:get(Jar, <<"session">>) of
        undefined -> {error, missing_cookie};
        Token -> verify_session(Token, Secret)
      end;
    _ ->
      {error, no_secret}
  end.

verify_session(Token, Secret) ->
  case errm_jwt:verify(Token, Secret, hs256) of
    {ok, Claims} ->
      case session_valid(maps:get(<<"sub">>, Claims, undefined),
                         maps:get(<<"ver">>, Claims, undefined)) of
        true -> {ok, Claims};
        false -> {error, stale_session}
      end;
    {error, Reason} ->
      {error, {invalid_token, Reason}}
  end.

session_valid(undefined, _Ver) -> false;
session_valid(Username, Ver) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT auth_version FROM accounts WHERE username = ? LIMIT 1",
            [Username]) of
        {ok, [Row]} -> maps:get("auth_version", Row) =:= Ver;
        _ -> false
      catch _:_ -> false
      end;
    {error, _} ->
      false
  end.

authenticate_manage(Req) ->
  Headers = maps:get(headers, Req, #{}),
  case maps:get(<<"authorization">>, Headers, undefined) of
    <<"Bearer ", Token/binary>> -> manage_lookup(Token);
    _ -> {error, invalid_token}
  end.

manage_lookup(Token) ->
  Hash = petring_token:hash(Token),
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT * FROM users WHERE manage_token_hash = ? LIMIT 1",
            [Hash]) of
        {ok, [Row]} ->
          touch_manage(Db, maps:get("username", Row, undefined)),
          {ok, Row};
        _ -> {error, invalid_token}
      catch _:_ -> {error, db_error}
      end;
    {error, _} ->
      {error, db_error}
  end.

touch_manage(Db, Username) when is_binary(Username) ->
  try errm_sqlite:exec(Db,
    "UPDATE users SET manage_token_last_used_at = ? WHERE username = ?",
    [erlang:system_time(second), Username]
  ) of
    {ok, _} -> ok
  catch _:_ -> ok
  end;
touch_manage(_, _) -> ok.



-spec get_claims(Req :: errm_http:request()) -> map() | undefined.
get_claims(Req) ->
  maps:get(claims, Req, undefined).

-spec get_manage_user(Req :: errm_http:request()) -> map().
get_manage_user(Req) ->
  maps:get(manage_user, Req, #{}).

to_segments(Path) when is_binary(Path) ->
  binary:split(Path, <<"/">>, [global, trim_all]);
to_segments(Path) when is_list(Path) ->
  [if is_binary(S) -> S; is_list(S) -> list_to_binary(S) end || S <- Path].
