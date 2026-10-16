-module (petring_notifications_ws).
-behaviour (errm_ws_handler).

-export ([upgrade/1, init/2, handle_text/2, handle_binary/2, handle_info/2, handle_ping/2, handle_pong/2, terminate/2]).

upgrade(Req) ->
  case petring_middlewares:get_claims(Req) of
    undefined -> petring_respond:error(401, <<"Unauthorized">>);
    _Claims -> {upgrade, errm_ws, {?MODULE, #{}}}
  end.

init(_RequestInfo, _Args) ->
  pg:join(petring_ws, petring_notifications, self()),
  {ok, #{}}.

handle_text(_Data, State) ->
  {ok, State}.

handle_binary(_Data, State) ->
  {ok, State}.

handle_info({broadcast, _Channel, Message}, State) ->
  errm_ws:send_text(self(), Message),
  {ok, State};
handle_info(_Info, State) ->
  {ok, State}.

handle_ping(_Data, State) ->
  {ok, State}.

handle_pong(_Data, State) ->
  {ok, State}.

terminate(_Reason, _State) ->
  pg:leave(petring_ws, petring_notifications, self()),
  ok.
