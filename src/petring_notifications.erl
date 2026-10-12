-module (petring_notifications).
-export ([record/6, get_all/0, clear/0]).

-spec record(Kind :: binary(), Action :: binary(), Username :: binary(), Content :: binary(), RefId :: binary(), Target :: binary()) -> ok.
record(Kind, Action, Username, Content, RefId, Target) ->
  Now = erlang:system_time(second),
  case petring_db:db() of
    {ok, Db} ->
      Result = try errm_sqlite:exec(Db,
            "INSERT INTO notifications (kind, action, username, content, ref_id, target, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            [Kind, Action, Username, Content, RefId, Target, Now]) of
        {ok, Changes} -> {ok, Changes}
      catch _:_ -> error
      end,
      case Result of
        {ok, _} ->
          Payload = payload(Kind, Action, Username, Content, RefId, Target, Now),
          petring_webhooks:dispatch(<<Kind/binary, ".", Action/binary>>, Payload),
          broadcast(Payload);
        error -> ok
      end;
    {error, _} -> ok
  end.

payload(Kind, Action, Username, Content, RefId, Target, Now) ->
  #{
    <<"event">> => <<"notification">>,
    <<"kind">> => Kind,
    <<"action">> => Action,
    <<"username">> => Username,
    <<"content">> => Content,
    <<"ref_id">> => RefId,
    <<"target">> => Target,
    <<"created_at">> => Now
  }.

broadcast(Payload) ->
  Encoded = errm_json:to_binary(Payload),
  Pids = pg:get_local_members(petring_ws, petring_notifications),
  [Pid ! {broadcast, petring_notifications, Encoded} || Pid <- Pids],
  ok.

-spec get_all() -> [map()].
get_all() ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT id, kind, action, username, content, ref_id, target, created_at "
            "FROM notifications ORDER BY created_at DESC, id DESC") of
        {ok, Rows} -> [petring_format:format_notification(Row) || Row <- Rows]
      catch _:_ -> []
      end;
    {error, _} -> []
  end.

-spec clear() -> ok.
clear() ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db, "DELETE FROM notifications") of
        {ok, _} -> ok
      catch _:_ -> ok
      end;
    {error, _} -> ok
  end.
