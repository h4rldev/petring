-module (petring_webhooks).
-export ([dispatch/2, deliver/3]).

-define (TIMEOUT, 10000).
-define (MAX_INFLIGHT, 16).

-spec dispatch(Event :: binary(), Payload :: map()) -> ok.
dispatch(Event, Payload) ->
  Hooks = matching(Event),
  Ref = inflight_ref(),
  [deliver_one(Ref, Hook, Event, Payload) || Hook <- Hooks],
  ok.

deliver_one(Ref, Hook, Event, Payload) ->
  counters:add(Ref, 1, 1),
  case counters:get(Ref, 1) =< ?MAX_INFLIGHT of
    true ->
      spawn(fun() ->
        try record_delivery(Hook, attempt(Hook, Event, Payload, 3))
        after counters:add(Ref, 1, -1)
        end
      end);
    false ->
      counters:add(Ref, 1, -1),
      logger:warning("petRing webhook delivery dropped, over ~p in flight; ~ts", [?MAX_INFLIGHT, maps:get("url", Hook, <<>>)])

  end.

inflight_ref() ->
  case persistent_term:get({?MODULE, inflight}, undefined) of
    undefined ->
      Ref = counters:new(1, []),
      persistent_term:put({?MODULE, inflight}, Ref),
      Ref;
    Ref -> Ref
  end.

attempt(Hook, Event, Payload, Retries) ->
  Result = deliver(Hook, Event, Payload),
  case delivered(Result) of
    true -> Result;
    false when Retries > 1 ->
      timer:sleep(2000 * (4 - Retries)),
      attempt(Hook, Event, Payload, Retries - 1);
    false -> Result
  end.

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
  Body = payload_body(Format, Event, Payload),
  post(Url, Body, signature_headers(Hook, Body)).

post(Url, Body, Headers) ->
  case petring_filter:ensure_http_clients() of
    ok ->
      HttpOptions = [{timeout, ?TIMEOUT}, {connect_timeout, ?TIMEOUT}, {ssl, [{verify, verify_none}]}],
      httpc:request(post, {binary_to_list(Url), Headers, "application/json", Body}, HttpOptions, [{body_format, binary}]);
    error ->
      {error, no_http_client}
  end.

signature_headers(Hook, Body) ->
  case maps:get("secret", Hook, undefined) of
    Secret when is_binary(Secret), Secret =/= <<>> ->                 
      Hex = binary:encode_hex(crypto:mac(hmac, sha256, Secret, Body), lowercase),
      [{"X-PetRing-Signature", "sha256=" ++ binary_to_list(Hex)}];
    _ -> []
  end.

payload_body(<<"discord">>, Event, Payload) ->
  errm_json:to_binary(discord_body(Event, Payload));
payload_body(<<"slack">>, Event, Payload) ->
  errm_json:to_binary(slack_body(Event, Payload));
payload_body(_Generic, _Event, Payload) ->
  errm_json:to_binary(Payload).

text(Event, Payload) ->
  Username = maps:get(<<"username">>, Payload, <<>>),
  Content = maps:get(<<"content">>, Payload, <<>>),
  iolist_to_binary(["petRing ", Event, ": ", display(Username), " (", display(Content), ")"]).

display(<<>>) -> <<"(none)">>;
display(undefined) -> <<"(none)">>;
display(null) -> <<"(none)">>;
display(V) -> V.

discord_body(Event, Payload) ->
  Embed0 = #{
    <<"title">> => Event,
    <<"description">> => display(maps:get(<<"content">>, Payload, <<>>)),
    <<"color">> => 16748544,
    <<"fields">> => [
      #{
        <<"name">> => <<"user">>,
        <<"value">> => display(maps:get(<<"username">>, Payload, <<>>)),
        <<"inline">> => true
      }
    ],
    <<"footer">> => #{<<"text">> => <<"petRing">>}
  },
  Embed = add_timestamp(Embed0, maps:get(<<"created_at">>, Payload, undefined)),
  case icon_url() of
    {ok, Icon} ->
      #{
        <<"username">> => <<"petRing">>,
        <<"avatar_url">> => Icon,
        <<"embeds">> => [Embed#{<<"thumbnail">> => #{<<"url">> => Icon}}]
      };
    error ->
      #{<<"username">> => <<"petRing">>, <<"embeds">> => [Embed]}
  end.

slack_body(Event, Payload) ->
  #{
    <<"text">> => text(Event, Payload),
    <<"attachments">> => [
      #{
        <<"color">> => <<"#ff9000">>,
        <<"title">> => Event,
        <<"fields">> => [
          #{
            <<"title">> => <<"user">>,
            <<"value">> => display(maps:get(<<"username">>, Payload, <<>>)),
            <<"short">> => true
          },
          #{
            <<"title">> => <<"content">>,
            <<"value">> => display(maps:get(<<"content">>, Payload, <<>>)),
            <<"short">> => false
          }
        ],
        <<"footer">> => <<"petRing">>
      }
    ]
  }.

add_timestamp(Embed, Secs) when is_integer(Secs) ->
  try Embed#{<<"timestamp">> => unicode:characters_to_binary(calendar:system_time_to_rfc3339(Secs))}
  catch _:_ -> Embed
  end;
add_timestamp(Embed, _) -> Embed.

delivered({ok, {{_, Status, _}, _, _}}) when Status >= 200, Status < 300 -> true;
delivered(_) -> false.

record_delivery(Hook, Result) ->
  Status = status_code(Result),
  Error = error_detail(Result),
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db,
            "UPDATE webhooks SET last_status = ?, last_error = ?, last_delivered_at = ? WHERE id = ?",
            [Status, Error, erlang:system_time(second), maps:get("id", Hook, null)]) of
        {ok, _} -> ok
      catch _:_ -> ok
      end;
    {error, _} -> ok
  end,
  report(Hook, Result).

status_code({ok, {{_, Status, _}, _, _}}) -> Status;
status_code(_) -> null.

error_detail({ok, {{_, Status, _}, _, _}}) when Status >= 200, Status < 300 -> null;
error_detail({ok, {{_, Status, _}, _, _}}) -> iolist_to_binary(["HTTP ", integer_to_list(Status)]);
error_detail(Other) -> iolist_to_binary(io_lib:format("~p", [Other])).

report(Hook, Result) ->
  case delivered(Result) of
    true -> ok;
    false -> logger:warning("PetRing webhook ~ts failed: ~p", [maps:get("url", Hook, <<>>), Result]), ok
  end.

icon_url() ->
  try iolist_to_binary([petring_config:get(server_url), "/paw.png"]) of
    Url -> {ok, Url}
  catch _:_ -> error
  end.
