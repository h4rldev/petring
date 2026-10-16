-module (petring_users).
-export ([submit/1]).

-spec submit(Req :: errm_http:request()) -> {ok, errm_http:response()}.
submit(Req) ->
  Ip = petring_ip:client_ip(Req),
  case petring_rate:attempt(Ip) of
    hard -> petring_respond:error(429, <<"Too many submissions from your network, please contact us.">>);
    soft -> petring_respond:error(429, <<"Too many submissions, please try again in a minute.">>);
    allow ->
      case body_map(Req) of
        {ok, Body} ->
          Username = maps:get(<<"username">>, Body, <<>>),
          Url = maps:get(<<"url">>, Body, <<>>),
          Contact = maps:get(<<"contact">>, Body, <<>>),
          do_submit(Username, Url, Contact, Ip);
        error ->
          petring_respond:error(400, <<"Invalid JSON body">>)
      end
  end.

do_submit(<<>>, _, _, _) ->
  petring_respond:error(400, <<"Invalid username">>);
do_submit(_, <<>>, _, _) ->
  petring_respond:error(400, <<"Invalid url">>);
do_submit(Username, Url, Contact, Ip) ->
  case petring_filter:url_allowed(<<"user_url">>, Url) of
    false -> petring_respond:error(400, <<"Invalid url">>);
    true -> insert(Username, Url, Contact, Ip)
  end.

insert(Username, Url, Contact, Ip) ->
  case petring_db:db() of
    {ok, Db} ->
      try
        case exists(Db, "SELECT 1 FROM users WHERE username = ? LIMIT 1", Username) of
          true ->
            petring_respond:error(409, <<"User already exists">>);
          false ->
            case exists(Db, "SELECT 1 FROM users WHERE url = ? LIMIT 1", Url) of
              true ->
                petring_respond:error(409, <<"Url already exists">>);
              false ->
                do_insert(Db, Username, Url, Contact, Ip)
            end
        end
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

do_insert(Db, Username, Url, Contact, Ip) ->
  Token = petring_token:mint(),
  Now = erlang:system_time(second),
  {ok, _} = errm_sqlite:exec(Db,
    "INSERT INTO users (username, url, contact, manage_token_hash, manage_token_created_at, submit_ip, verified, created_at) "
    "VALUES (?, ?, ?, ?, ?, ?, 0, ?)",
    [Username, Url, Contact, petring_token:hash(Token), Now, Ip, Now]),
  petring_rate:record(Ip),
  petring_notifications:record(<<"user">>, <<"submit">>, Username, Url, <<>>, <<>>),
  {ok, [Row]} = errm_sqlite:query(Db,
    "SELECT * FROM users WHERE username = ? LIMIT 1", [Username]),
  petring_respond:ok(
    #{<<"user">> => petring_format:format_user(Row), <<"manage_token">> => Token},
    [<<"user">>, <<"manage_token">>]).

exists(Db, Sql, Value) ->
  case errm_sqlite:query(Db, Sql, [Value]) of
    {ok, [_ | _]} -> true;
    _ -> false
  end.

body_map(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Map} when is_map(Map) -> {ok, Map};
    _ -> error
  end.
