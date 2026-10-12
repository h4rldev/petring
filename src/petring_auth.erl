-module (petring_auth).
-export ([ensure_superadmin/0, login/1, logout/1, me/1, list_accounts/1, create_account/1,
         delete_account/1, change_password/1]).

-define (SESSION_TTL, 30 * 86400).

-spec ensure_superadmin() -> ok.
ensure_superadmin() -> 
  User = env_str("PETRING_SUPERADMIN_USER", "superadmin"),
  Pass = env_str("PETRING_SUPERADMIN_PASS", "superadmin"),

  case petring_db:db() of
    {ok, Db} ->
      seed_superadmin(Db, User, Pass);
    {error, _} -> ok
  end.

seed_superadmin(Db, User, Pass) ->
  Hash = hash_password(Pass),
  
  try
    case fetch_superadmin(Db) of
      {ok, Row} ->
        case maps:get("updated_at", Row, null) of
          null ->
            errm_sqlite:exec(Db,
              "UPDATE accounts SET username = ?, password_hash = ? WHERE username = ?",
              [User, Hash, maps:get("username", Row)]);
          _ ->
            ok
        end;
      {error, not_found} ->
        errm_sqlite:exec(Db,
          "INSERT INTO accounts (username, password_hash, role) VALUES (?, ?, 'superadmin')",
          [User, Hash])
    end
  catch _:_ -> ok
  end.

fetch_superadmin(Db) ->
  try errm_sqlite:query(Db,
        "SELECT username, updated_at FROM accounts WHERE role = 'superadmin' LIMIT 1", []) of
    {ok, [Row | _]} -> {ok, Row};
    _ -> {error, not_found}
  catch _:_ -> {error, not_found}
  end.

-spec login(Req :: errm_http:request()) -> {ok, errm_http:response()}.
login(Req) ->
  case body_map(Req) of
    {ok, Body} ->
      Username = maps:get(<<"username">>, Body, <<>>),
      Password = maps:get(<<"password">>, Body, <<>>),
      do_login(Username, Password);
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

do_login(Username, Password) ->
  case fetch_account(Username) of
    {ok, Account} ->
      case verify_password(Password, maps:get("password_hash", Account)) of
        true -> issue_session(Account);
        false -> petring_respond:error(401, <<"Invalid credentials">>)
      end;
    {error, _} ->
      petring_respond:error(401, <<"Invalid credentials">>)
  end.

issue_session(Account) ->
  case petring_secrets:get_jwt_secret() of
    {ok, Secret} when is_binary(Secret) ->
      Username = maps:get("username", Account),
      Role = maps:get("role", Account),
      Ver = maps:get("auth_version", Account),
      Claims = #{<<"sub">> => Username, <<"role">> => Role, <<"ver">> => Ver},
      case errm_jwt:sign(Claims, Secret, hs256, #{ttl => ?SESSION_TTL}) of
        {ok, Token} ->
          Cookie = errm_http_cookie:set_cookie(<<"session">>, Token,
            #{path => <<"/">>, http_only => true, same_site => lax, max_age => ?SESSION_TTL}),
          {ok, Response} = petring_respond:ok(
            #{<<"username">> => Username, <<"role">> => Role},
            [<<"username">>, <<"role">>]),
          {ok, errm_http_cookie:add_cookies(Response, [Cookie])};
        {error, _} ->
          petring_respond:error(500, <<"Failed to issue session">>)
      end;
    _ ->
      petring_respond:error(500, <<"No JWT secret">>)
  end.

-spec logout(Req :: errm_http:request()) -> {ok, errm_http:response()}.
logout(_Req) ->
  Cookie = errm_http_cookie:set_cookie(<<"session">>, <<>>,
    #{path => <<"/">>, max_age => 0}),
  {ok, Response} = petring_respond:ok(#{<<"message">> => <<"Logged out">>}, [<<"message">>]),
  {ok, errm_http_cookie:add_cookies(Response, [Cookie])}.

-spec me(Req :: errm_http:request()) -> {ok, errm_http:response()}.
me(Req) ->
  case petring_middlewares:get_claims(Req) of
    undefined ->
      petring_respond:error(401, <<"Unauthorized">>);
    Claims ->
      petring_respond:ok(#{
        <<"username">> => maps:get(<<"sub">>, Claims, null),
        <<"role">> => maps:get(<<"role">>, Claims, null)
      }, [<<"username">>, <<"role">>])
  end.

-spec list_accounts(Req :: errm_http:request()) -> {ok, errm_http:response()}.
list_accounts(_Req) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT username, role, auth_version, created_at, updated_at "
            "FROM accounts ORDER BY id ASC", []) of
        {ok, Rows} ->
          petring_respond:ok(
            #{<<"accounts">> => [petring_format:format_account(R) || R <- Rows]},
            [<<"accounts">>]);
        _ ->
          petring_respond:error(500, <<"Database error">>)
      catch _:_ -> petring_respond:error(500, <<"Database error">>) end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec create_account(Req :: errm_http:request()) -> {ok, errm_http:response()}.
create_account(Req) ->
  case body_map(Req) of
    {ok, Body} ->
      Username = maps:get(<<"username">>, Body, <<>>),
      Password = maps:get(<<"password">>, Body, <<>>),
      Role = maps:get(<<"role">>, Body, <<"admin">>),
      do_create_account(Req, Username, Password, Role);
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

do_create_account(Req, Username, Password, Role) ->
  Acting = acting_role(Req),
  case {valid_username(Username), valid_role(Role), can_create(Acting, Role)} of
    {false, _, _} -> petring_respond:error(400, <<"Invalid username">>);
    {_, false, _} -> petring_respond:error(400, <<"Invalid role">>);
    {_, _, false} -> petring_respond:error(403, <<"Forbidden">>);
    {true, true, true} -> insert_account(Username, Password, Role)
  end.

can_create(<<"superadmin">>, <<"admin">>) -> true;
can_create(_Acting, _Role) -> false.

insert_account(Username, Password, Role) ->
  case petring_db:db() of
    {ok, Db} ->
      Hash = hash_password(Password),
      try errm_sqlite:exec(Db,
            "INSERT INTO accounts (username, password_hash, role) VALUES (?, ?, ?)",
            [Username, Hash, Role]) of
        {ok, _} ->
          petring_respond:ok(#{<<"username">> => Username, <<"role">> => Role},
            [<<"username">>, <<"role">>]);
        _ ->
          petring_respond:error(409, <<"Account already exists">>)
      catch _:_ -> petring_respond:error(409, <<"Account already exists">>) end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec delete_account(Req :: errm_http:request()) -> {ok, errm_http:response()}.
delete_account(Req) ->
  Name = name_param(Req),
  case Name =:= maps:get(<<"sub">>, claims(Req), <<>>) of
    true -> petring_respond:error(400, <<"Cannot delete yourself">>);
    false -> delete_account_row(Req, Name)
  end.

delete_account_row(Req, Name) ->
  case fetch_account(Name) of
    {ok, Account} ->
      TargetRole = maps:get("role", Account),
      case can_manage(claims(Req), TargetRole) of
        true -> remove_account(Name);
        false -> petring_respond:error(403, <<"Forbidden">>)
      end;
    {error, _} ->
      petring_respond:error(404, <<"Account not found">>)
  end.

remove_account(Name) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db, "DELETE FROM accounts WHERE username = ?", [Name]) of
        {ok, Changes} when Changes > 0 ->
          petring_respond:ok(#{<<"message">> => <<"Account deleted">>}, [<<"message">>]);
        _ ->
          petring_respond:error(404, <<"Account not found">>)
      catch _:_ -> petring_respond:error(500, <<"Database error">>) end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec change_password(Req :: errm_http:request()) -> {ok, errm_http:response()}.
change_password(Req) ->
  Name = name_param(Req),
  case body_map(Req) of
    {ok, Body} ->
      Password = maps:get(<<"password">>, Body, <<>>),
      Acting = maps:get(<<"sub">>, claims(Req), <<>>),
      case Name =:= Acting orelse target_manageable(Req, Name) of
        true -> set_password(Name, Password);
        false -> petring_respond:error(403, <<"Forbidden">>)
      end;
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

set_password(Name, Password) ->
  case petring_db:db() of
    {ok, Db} ->
      Hash = hash_password(Password),
      try errm_sqlite:exec(Db,
            "UPDATE accounts SET password_hash = ?, auth_version = auth_version + 1, "
            "updated_at = ? WHERE username = ?",
            [Hash, now_secs(), Name]) of
        {ok, Changes} when Changes > 0 ->
          petring_respond:ok(#{<<"message">> => <<"Password updated">>}, [<<"message">>]);
        _ ->
          petring_respond:error(404, <<"Account not found">>)
      catch _:_ -> petring_respond:error(500, <<"Database error">>) end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec rank(binary()) -> non_neg_integer().
rank(<<"superadmin">>) -> 2;
rank(<<"admin">>) -> 1;
rank(_) -> 0.

-spec can_manage(map(), binary()) -> boolean().
can_manage(Claims, TargetRole) ->
  rank(maps:get(<<"role">>, Claims, <<>>)) > rank(TargetRole).

target_manageable(Req, Name) ->
  case fetch_account(Name) of
    {ok, Account} ->
      can_manage(claims(Req), maps:get("role", Account));
    {error, _} ->
      false
  end.

fetch_account(Username) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT * FROM accounts WHERE username = ? LIMIT 1", [Username]) of
        {ok, [Row | _]} -> {ok, Row};
        _ -> {error, not_found}
      catch _:_ -> {error, not_found} end;
    {error, _} ->
      {error, db_error}
  end.

claims(Req) -> petring_middlewares:get_claims(Req).

acting_role(Req) -> maps:get(<<"role">>, claims(Req), <<>>).

valid_username(Username) when is_binary(Username) ->
  Size = byte_size(Username),
  Size > 0 andalso Size =< 32 andalso valid_chars(Username);
valid_username(_) ->
  false.

valid_chars(<<>>) -> true;
valid_chars(<<C, Rest/binary>>)
    when C >= $a, C =< $z; C >= $A, C =< $Z; C >= $0, C =< $9;
         C =:= $.; C =:= $_; C =:= $- ->
  valid_chars(Rest);
valid_chars(_) -> false.

valid_role(<<"superadmin">>) -> true;
valid_role(<<"admin">>) -> true;
valid_role(_) -> false.

hash_password(Password) ->
  case errm_argon:hash(binary_to_list(iolist_to_binary(Password))) of
    {ok, Hash} -> Hash;
    {error, Reason} -> throw({hash_failed, Reason})
  end.

verify_password(Password, Hash) when is_binary(Hash) ->
  errm_argon:verify(binary_to_list(iolist_to_binary(Password)), Hash);
verify_password(_, _) ->
  false.

body_map(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Map} when is_map(Map) -> {ok, Map};
    _ -> error
  end.

name_param(Req) ->
  maps:get(<<"name">>, maps:get(params, Req, #{}), <<>>).

env_str(Key, Default) ->
  case os:getenv(Key) of
    false -> Default;
    "" -> Default;
    Value -> Value
  end.

now_secs() -> erlang:system_time(second).
