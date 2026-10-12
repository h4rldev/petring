-module (petring_webhooks).
-export ([dispatch/2, deliver/3]).

-define (TIMEOUT, 10000).

-spec dispatch(Event :: binary(), Payload :: map()) -> ok.
dispatch(Event, Payload) ->
  Hooks = matching(Event),
  [spawn(fun() -> log_delivery(Hook, deliver(Hook, Event, Payload)) end) || Hook <- Hooks],
  ok.

matching(Event) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db, "SELECT * FROM webhooks WHERE enabled = 1", []) of
        {ok, Rows} -> [Row || Row <- Rows, matches(maps:get("events", Row, <<"[]">>), Event)];
        _ -> []
      catch _:_ -> []
      end;
    {error, _} -> []
  end.

matches(Raw, Event) ->
  Events = decode_array(Raw),
  lists:member(<<"*">>, Events) orelse lists:member(Event, Events).

decode_array(Raw) ->
  case errm_json:decode(Raw) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

-spec deliver(Hook :: map(), Event :: binary(), Payload :: map()) -> term().
deliver(Hook, Event, Payload) ->
  Url = maps:get("url", Hook, <<>>),
  Format = maps:get("format", Hook, <<"generic">>),
  post(Url, payload_body(Format, Event, Payload)).

post(Url, Body) ->
  case petring_filter:ensure_http_clients() of
    ok ->
      HttpOptions = [{timeout, ?TIMEOUT}, {connect_timeout, ?TIMEOUT}, {ssl, [{verify, verify_none}]}],
      httpc:request(post, {binary_to_list(Url), [], "application/json", Body}, HttpOptions, [{body_format, binary}]);
    error ->
      {error, no_http_client}
  end.

payload_body(<<"discord">>, Event, Payload) ->
  errm_json:to_binary(#{<<"content">> => text(Event, Payload)});
payload_body(<<"slack">>, Event, Payload) ->
  errm_json:to_binary(#{<<"text">> => text(Event, Payload)});
payload_body(_Generic, _Event, Payload) ->
  errm_json:to_binary(Payload).

text(Event, Payload) ->
  Username = maps:get(<<"username">>, Payload, <<>>),
  Content = maps:get(<<"content">>, Payload, <<>>),
  iolist_to_binary(["PetRing ", Event, ": ", display(Username), " (", display(Content), ")"]).

display(<<>>) -> <<"(none)">>;
display(undefined) -> <<"(none)">>;
display(null) -> <<"(none)">>;
display(V) -> V.

log_delivery(_Hook, {ok, {{_, Status, _}, _, _}}) when Status >= 200, Status < 300 -> ok;
log_delivery(Hook, Result) ->
  logger:warning("PetRing webhook ~ts failed: ~p", [maps:get("url", Hook, <<>>), Result]),
  ok.
