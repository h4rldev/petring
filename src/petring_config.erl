-module (petring_config).
-export ([load/0, get/1]).

-record(config, {
  port :: non_neg_integer(),
  internal_log_level :: string(),
  db_path :: string(),
  server_name :: string(),
  server_url :: string(),
  cors_origins :: [binary()],
  cors_credentials :: boolean(),
  url_reachability :: boolean(),
  log_access :: boolean(),
  access_log_file :: string()
}).

-spec load() -> ok.
load() ->
  Defaults = #config{
    port = 8080,
    internal_log_level = "info",
    db_path = "petring.db",
    server_name = "petring",
    server_url = "https://your-domain.example",
    cors_origins = [<<"*">>],
    cors_credentials = false,
    url_reachability = false,
    log_access = true,
    access_log_file = ""
  },

  Config = 
    case file:read_file("petring-config.json") of
      {ok, Data} ->
        case errm_json:decode_stream(Data) of
          {ok, Decoded, _Rest} when is_map(Decoded) ->
             from_json(Decoded, Defaults);
          {error, Reason} ->
            logger:warning("Failed to decode config file: ~p, using defaults", [Reason]),
            Defaults
        end;
      {error, enoent} ->
        Json = errm_json:encode(record_to_map(Defaults), #{pretty => true, indent => 2}),
        file:write_file("petring-config.json", Json),
        Defaults;
      {error, Reason1} ->
        logger:warning("Failed to read config file: ~p, using defaults", [Reason1]),
        Defaults
    end,
  
  errm_http:set_secret(config, Config),
  ok.

from_json(Decoded, Defaults) ->
  #config{
    port = json_to_port(maps:get(<<"port">>, Decoded, Defaults#config.port), Defaults#config.port),
    internal_log_level = json_to_string(maps:get(<<"internal_log_level">>, Decoded, Defaults#config.internal_log_level)),
    db_path = json_to_string(maps:get(<<"db_path">>, Decoded, Defaults#config.db_path)),
    server_name = json_to_string(maps:get(<<"server_name">>, Decoded, Defaults#config.server_name)),
    server_url = json_to_string(maps:get(<<"server_url">>, Decoded, Defaults#config.server_url)),
    cors_origins = json_to_origins(maps:get(<<"cors_origins">>, Decoded, Defaults#config.cors_origins), Defaults#config.cors_origins),
    cors_credentials = json_to_bool(maps:get(<<"cors_credentials">>, Decoded, Defaults#config.cors_credentials), Defaults#config.cors_credentials),
    url_reachability = json_to_bool(maps:get(<<"url_reachability">>, Decoded, Defaults#config.url_reachability), Defaults#config.url_reachability),
    log_access = json_to_bool(maps:get(<<"log_access">>, Decoded, Defaults#config.log_access), Defaults#config.log_access),
    access_log_file = json_to_string(maps:get(<<"access_log_file">>, Decoded, Defaults#config.access_log_file))
  }.

json_to_port(P, _Default) when is_integer(P) -> P;
json_to_port(P, Default) when is_binary(P) ->
  try binary_to_integer(P) catch error:badarg -> Default end;
json_to_port(_, Default) -> Default.

json_to_bool(B, _Default) when is_boolean(B) -> B;
json_to_bool(_, Default) -> Default.

json_to_origins(<<"*">>, _Default) -> [<<"*">>];
json_to_origins(L, Default) when is_list(L) ->
  case [O || O <- L, is_binary(O)] of
    [] -> Default;
    Origins -> Origins
  end;
json_to_origins(_, Default) -> Default.

json_to_string(V) when is_binary(V) -> binary_to_list(V);
json_to_string(V) when is_list(V) -> V;
json_to_string(_) -> "".

record_to_map(#config{} = Record) ->
  Fields = record_info(fields, config),
  maps:from_list(lists:zip(Fields, tl(tuple_to_list(Record)))).

get(Key) ->
  Config =
    case errm_http:get_secret(config) of
      {ok, Secret} when is_record(Secret, config) ->
        Secret;
      _ -> throw({error, config_not_found})
    end,
  
  case Key of
    port -> Config#config.port;
    internal_log_level -> Config#config.internal_log_level;
    db_path -> Config#config.db_path;
    server_name -> Config#config.server_name;
    server_url -> Config#config.server_url;
    cors_origins -> Config#config.cors_origins;
    cors_credentials -> Config#config.cors_credentials;
    url_reachability -> Config#config.url_reachability;
    log_access -> Config#config.log_access;
    access_log_file -> Config#config.access_log_file;
    _ -> undefined
  end.
