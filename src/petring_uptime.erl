-module (petring_uptime).
-export ([app_uptime/0, system_uptime/0, format_duration/1]).

-spec app_uptime() -> integer().
app_uptime() ->
  Start = persistent_term:get(petring_start_time, erlang:system_time(second)),
  erlang:system_time(second) - Start.

-spec system_uptime() -> integer().
system_uptime() ->
  case file:read_file("/proc/uptime") of
    {ok, Data} ->
      case binary:split(Data, <<" ">>, [global]) of
        [First | _] ->
          try trunc(binary_to_float(First)) catch _:_ -> 0 end;
        _ -> 0
      end;
    _ -> 0
  end.

-spec format_duration(integer()) -> binary().
format_duration(Seconds) when Seconds =< 0 -> <<"0s">>;
format_duration(Seconds) ->
  Parts = units(Seconds, [{86400, "d"}, {3600, "h"}, {60, "m"}, {1, "s"}], []),
  iolist_to_binary(lists:join(<<" ">>, lists:reverse(Parts))).

units(_Remaining, [], Acc) -> Acc;
units(Remaining, [{Size, Unit} | Rest], Acc) ->
  Value = Remaining div Size,
  Acc1 = case Value of
    0 -> Acc;
    _ -> [[integer_to_binary(Value), Unit] | Acc]
  end,
  units(Remaining rem Size, Rest, Acc1).
