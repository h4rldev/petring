-module (petring_access_log).
-export ([middleware/0, clear/0]).

middleware() ->
  Enabled = 
    case petring_config:get(log_access) of
      true -> true;
      _ -> false
    end,

  File = petring_config:get(access_log_file),
  fun(Req, Next) ->
    case Enabled of
      false ->
        Next(Req);
      true ->
        log(Req, Next, File)
    end
  end.

-spec log(Req :: errm_http:request(), Next :: fun(), File :: string()) -> errm_http:middleware().
log(Req, Next, File) ->
  Start = erlang:monotonic_time(microsecond),
  Result = Next(Req),
  Duration = erlang:monotonic_time(microsecond) - Start,
  Line = io_lib:format("~s ~s -> ~p from ~s (~p µs)~n", [
    string:uppercase(atom_to_binary(maps:get(method, Req, get), utf8)),
    maps:get(raw_path, Req, <<"/">>),
    status_of(Result),
    petring_ip:client_ip(Req),
    Duration
  ]),
  write(File, Line),
  Result.

-spec clear() -> ok | {error, no_file | term()}.
clear() ->
  case petring_config:get(access_log_file) of
    "" -> {error, no_file};
    File ->
      case file:write_file(File, <<>>) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
      end
  end.

-spec write(File :: string(), Line :: unicode:chardata()) -> ok.
write("", Line) ->
  logger:info("~ts", [Line]);
write(File, Line) ->
  Time = calendar:system_time_to_rfc3339(erlang:system_time(microsecond), [{unit, microsecond}]),
  case unicode:characters_to_binary([Time, " ", Line]) of
    Bin when is_binary(Bin) ->
      case file:write_file(File, Bin, [append]) of
        ok -> ok;
        {error, Reason} ->
          logger:error("Failed to append access log ~s: ~p", [File, Reason])
      end;
    EncodingError ->
      logger:error("Failed to encode access log line: ~p", [EncodingError])
  end.

-spec status_of(term()) -> integer() | atom().
status_of({ok, {Status, _Headers, _Body}}) when is_integer(Status) -> Status;
status_of({error, Reason}) when is_atom(Reason) -> Reason;
status_of({upgrade, _Module, _Args}) -> 101;
status_of(_) -> undefined.
