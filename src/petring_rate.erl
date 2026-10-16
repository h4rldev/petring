-module (petring_rate).
-export ([start/0, attempt/1, record/1]).

-define (TABLE, petring_rate).
-define (SOFT_WINDOW, 60).
-define (SOFT_MAX, 5).
-define (HARD_WINDOW, 1209600).
-define (HARD_MAX, 100).

-spec start() -> ok.
start() ->
  spawn(fun() ->
    ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}, {write_concurrency, true}]),
    sweep()
  end),
  ok.

sweep() ->
  receive stop -> ok
  after 60000 ->
    Hard = erlang:system_time(second) div ?HARD_WINDOW,
    ets:select_delete(?TABLE, [{{'$1', '_', '_', '$2', '_'}, [{'<', '$2', Hard}], [true]}]),
    sweep()
  end.

-spec attempt(Key :: binary()) -> allow | soft | hard.
attempt(Key) ->
  SoftWin = erlang:system_time(second) div ?SOFT_WINDOW,
  HardWin = erlang:system_time(second) div ?HARD_WINDOW,
  {Scount, Hcount} = counts(Key, SoftWin, HardWin),
  if
    Hcount >= ?HARD_MAX -> hard;
    Scount >= ?SOFT_MAX -> soft;
    true ->
      ets:insert(?TABLE, {Key, SoftWin, Scount + 1, HardWin, Hcount}),
      allow
  end.

-spec record(Key :: binary()) -> ok.
record(Key) ->
  SoftWin = erlang:system_time(second) div ?SOFT_WINDOW,
  HardWin = erlang:system_time(second) div ?HARD_WINDOW,
  {Scount, Hcount} = counts(Key, SoftWin, HardWin),
  ets:insert(?TABLE, {Key, SoftWin, Scount, HardWin, Hcount + 1}),
  ok.

counts(Key, SoftWin, HardWin) ->
  case ets:lookup(?TABLE, Key) of
    [{Key, S, Sc, H, Hc}] -> {reset(S, SoftWin, Sc), reset(H, HardWin, Hc)};
    _ -> {0, 0}
  end.

reset(Win, Win, Count) -> Count;
reset(_, _, _) -> 0.
