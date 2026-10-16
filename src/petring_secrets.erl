-module (petring_secrets).
-export ([init/0, get_jwt_secret/0]).

-spec init() -> ok.
init() ->
  get_or_gen("JWT_SECRET").

-spec get_jwt_secret() -> {ok, Secret :: binary()} | {error, not_found}.
get_jwt_secret() ->
  case errm_http:get_secret(jwt_secret) of
    {ok, Value} when is_binary(Value) ->
      {ok, Value};
    _ ->
      get_or_gen("JWT_SECRET"),
      get_jwt_secret()
  end.

get_or_gen(Key) ->
  case env_get(Key) of
    {ok, Value} ->
      errm_http:set_secret(jwt_secret, debase64(Value)),
      ok;
    _ ->
      gen()
  end.

gen() ->
  Secret = crypto:strong_rand_bytes(32),
  Base64 = base64:encode(Secret, #{mode => urlsafe, padding => false}),
  set_env_var("JWT_SECRET", Base64),
  errm_http:set_secret(jwt_secret, Secret),
  ok.

debase64(Val) ->
  base64:decode(Val, #{mode => urlsafe, padding => false}).

env_get(Key) ->
  case os:getenv(Key) of
    false -> errm_env:get(Key, "petring.env");
    "" -> errm_env:get(Key, "petring.env");
    Value -> {ok, Value}
  end.

set_env_var(Key, Value) ->
  KeyBin = list_to_binary(Key),
  ValBin = case Value of
    Bin when is_binary(Bin) -> Bin;
    Str -> list_to_binary(Str)
  end,
  os:putenv(Key, binary_to_list(ValBin)),
  NewLine = <<KeyBin/binary, "=", ValBin/binary, "\n">>,
  case file:read_file("petring.env") of
    {ok, Content} ->
      Lines = binary:split(Content, <<"\n">>, [global]),
      Filtered = [L || L <- Lines,
        L =/= <<>>,
        case binary:match(L, <<KeyBin/binary, "=">>) of
          {0, _} -> false;
          _ -> true
        end],
      file:write_file("petring.env", binary:join(Filtered ++ [NewLine], <<"\n">>));
    {error, enoent} ->
      file:write_file("petring.env", NewLine)
  end.
