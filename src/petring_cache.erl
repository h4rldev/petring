-module (petring_cache).
-include_lib ("kernel/include/file.hrl").
-export ([middleware/1]).

-spec middleware([{binary(), binary()}]) -> errm_http:middleware().
middleware(Rules) ->
  fun(Req, Next) ->
    case Next(Req) of
      {ok, {Status, Headers, Body}} ->
        {ok, respond(Status, Headers, Body, Req, Rules)};
      Other ->
        Other
    end
  end.

respond(Status, Headers, Body, Req, Rules) ->
  Path = maps:get(raw_path, Req, <<"/">>),
  Headers1 = with_cache_control(Headers, Path, Rules),
  case maps:get(<<"content-type">>, Headers1, <<>>) of
    <<"text/html", _/binary>> -> revalidate(Status, Headers1, Body, Req);
    _ -> {Status, Headers1, Body}
  end.

revalidate(Status, Headers, Body, Req) ->
  Headers1 = case maps:is_key(<<"cache-control">>, Headers) of
               true -> Headers;
               false -> Headers#{<<"cache-control">> => <<"no-cache">>}
             end,
  case etag(Body) of
    undefined ->
      {Status, Headers1, Body};
    ETag ->
      Headers2 = Headers1#{<<"etag">> => ETag},
      case etag_matches(Req, ETag) of
        true -> {304, maps:remove(<<"content-length">>, Headers2), <<>>};
        false -> {Status, Headers2, Body}
      end
  end.

with_cache_control(Headers, Path, Rules) ->
  case maps:is_key(<<"cache-control">>, Headers) of
    true -> Headers;
    false ->
      case rule_for(Path, Rules) of
        undefined -> Headers;
        Value -> Headers#{<<"cache-control">> => Value}
      end
  end.

rule_for(_Path, []) -> undefined;
rule_for(Path, [{Prefix, Value} | Rest]) ->
  case string:prefix(Path, Prefix) of
    nomatch -> rule_for(Path, Rest);
    _ -> Value
  end.

etag({file, FilePath}) ->
  case file:read_file_info(FilePath) of
    {ok, #file_info{size = Size, mtime = MTime}} when is_integer(Size), is_tuple(MTime) ->
      Seconds = calendar:datetime_to_gregorian_seconds(MTime),
      iolist_to_binary([$", integer_to_list(Size), $-, integer_to_list(Seconds), $"]) ;
    _ ->
      undefined
  end;
etag(Body) when is_binary(Body) ->
  iolist_to_binary([$", integer_to_list(byte_size(Body)), $-, integer_to_list(erlang:crc32(Body)), $"]);
etag(_) ->
  undefined.

etag_matches(Req, ETag) ->
  Headers = maps:get(headers, Req, #{}),
  case maps:get(<<"if-none-match">>, Headers, undefined) of
    undefined -> false;
    Value ->
      Candidates = [string:trim(T) || T <- binary:split(Value, <<",">>, [global])],
      lists:member(ETag, Candidates) orelse lists:member(<<"*">>, Candidates)
  end.
