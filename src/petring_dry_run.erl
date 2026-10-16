-module (petring_dry_run).
-export ([middleware/0]).

-spec middleware() -> errm_http:middleware().
middleware() ->
  fun(Req, Next) ->
    case requested(Req) of
      true -> echo(Req);
      false -> Next(Req)
    end
  end.

requested(Req) ->
  is_api(maps:get(raw_path, Req, <<>>)) andalso has_header(maps:get(headers, Req, #{})).

is_api(<<"/api/", _/binary>>) -> true;
is_api(_) -> false.

has_header(Headers) ->
  case maps:get(<<"x-dry-run">>, Headers, undefined) of
    undefined -> false;
    Value -> lists:member(string:lowercase(Value), [<<"true">>, <<"1">>, <<"yes">>])
  end.

echo(Req) ->
  Method = string:uppercase(atom_to_binary(maps:get(method, Req, get), utf8)),
  Path = maps:get(raw_path, Req, <<"/">>),
  petring_respond:ok(
    #{<<"dry_run">> => true, <<"method">> => Method,
      <<"path">> => Path, <<"body">> => body(maps:get(body, Req, <<>>))},
    [<<"dry_run">>, <<"method">>, <<"path">>, <<"body">>]).

body(<<>>) -> null;
body(Bin) ->
  case errm_json:decode(Bin) of
    {ok, Value} -> Value;
    _ -> null
  end.
