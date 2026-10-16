-module (petring_ip).
-export ([client_ip/1]).

-spec client_ip(Req :: errm_http:request()) -> binary().
client_ip(Req) ->
  Headers = maps:get(headers, Req, #{}),
  case header(Headers, <<"x-forwarded-for">>) of
    undefined ->
      case header(Headers, <<"x-real-ip">>) of
        undefined -> peer_ip(Req);
        Real -> trim(Real)
      end;
    Forwarded ->
      first_hop(Forwarded)
  end.

header(Headers, Key) ->
  case maps:get(Key, Headers, undefined) of
    V when is_binary(V), V =/= <<>> -> V;
    _ -> undefined
  end.

first_hop(Forwarded) ->
  case binary:split(Forwarded, <<",">>) of
    [First | _] -> trim(First);
    _ -> trim(Forwarded)
  end.


trim(Bin) -> string:trim(Bin).

peer_ip(Req) ->
  case maps:get(peer, Req, undefined) of
    {IP, _Port} ->
      case inet:ntoa(IP) of
        {error, _} -> <<"unknown">>;
        Str -> list_to_binary(Str)
      end;
    _ -> <<"unknown">>
  end.
