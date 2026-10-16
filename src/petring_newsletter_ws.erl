-module (petring_newsletter_ws).
-behaviour (errm_ws_handler).

-export ([upgrade/1, init/2, handle_text/2, handle_binary/2, handle_info/2, handle_ping/2, handle_pong/2, terminate/2]).
-export ([broadcast/2]).

upgrade(_Req) ->
  {upgrade, errm_ws, {?MODULE, #{}}}.

init(_RequestInfo, _Args) ->
  pg:join(petring_ws, petring_newsletter, self()),
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
  pg:leave(petring_ws, petring_newsletter, self()),
  ok.

-spec broadcast(Action :: binary(), Entry :: map()) -> ok.
broadcast(Action, Entry) ->
  Payload = #{<<"event">> => <<"newsletter">>, <<"action">> => Action, <<"entry">> => Entry},
  Encoded = errm_json:to_binary(Payload),
  Pids = pg:get_local_members(petring_ws, petring_newsletter),
  [Pid ! {broadcast, petring_newsletter, Encoded} || Pid <- Pids],
  ok.
