-module (petring).
-export ([start/0, stop/0, main/1]).

-spec start() -> {ok, pid()}.
start() ->
  petring_config:load(),
  petring_secrets:init(),
  petring_db:init(),
  petring_auth:ensure_superadmin(),
  {ok, _} = pg:start_link(petring_ws),

  set_log_level(petring_config:get(internal_log_level)),
  logger:update_handler_config(default, formatter,
    {logger_formatter, #{legacy_header => false, single_line => true}}),

  persistent_term:put(petring_start_time, erlang:system_time(second)),
  {ok, Pid} = errm_http:start(#{
    server_name => petring_config:get(server_name),
    port => petring_config:get(port),
    routes => petring_routes:get(),
    middlewares => petring_middlewares:get(),
    error_handlers => petring_respond:error_handlers()
  }),

  logger:info("petRing listening on port ~p", [petring_config:get(port)]),
  {ok, Pid}.

-spec stop() -> ok.
stop() ->
  errm_http:stop().

-spec main([string()]) -> ok.
main(_Args) ->
  start(),
  receive stop -> stop() end.

set_log_level(Level) ->
  Atom = case string:lowercase(Level) of
    "emergency" -> emergency;
    "alert" -> alert;
    "critical" -> critical;
    "error" -> error;
    "err" -> error;
    "warning" -> warning;
    "warn" -> warning;
    "notice" -> notice;
    "info" -> info;
    "debug" -> debug;
    "all" -> all;
    "none" -> none;
    _ -> info
  end,
  logger:set_primary_config(level, Atom).
