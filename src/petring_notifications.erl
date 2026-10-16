-module (petring_notifications).
-export ([record/6, get_all/0, mark_read/1, clear/0]).

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
          Payload = payload(last_id(Db), Kind, Action, Username, Content, RefId, Target, Now),
          petring_webhooks:dispatch(<<Kind/binary, ".", Action/binary>>, Payload),
          broadcast(Payload);
        error -> ok
      end;
    {error, _} -> ok
  end.

payload(Id, Kind, Action, Username, Content, RefId, Target, Now) ->
  #{
    <<"id">> => Id,
    <<"event">> => <<"notification">>,
    <<"kind">> => Kind,
    <<"action">> => Action,
    <<"username">> => Username,
    <<"content">> => Content,
    <<"ref_id">> => RefId,
    <<"target">> => Target,
    <<"read">> => false,
    <<"created_at">> => Now
  }.

last_id(Db) ->
  case errm_sqlite:scalar(Db, "SELECT last_insert_rowid()") of
    {ok, Id} -> Id;
    _ -> null
  end.

broadcast(Payload)->
  Encoded = errm_json:to_binary(Payload),
  Pids = pg:get_local_members(petring_ws, petring_notifications),
  [Pid ! {broadcast, petring_notifications, Encoded} || Pid <- Pids],
  ok.

-spec get_all() -> [map()].
get_all() ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db,
            "SELECT id, kind, action, username, content, ref_id, target, read, created_at "
            "FROM notifications ORDER BY created_at DESC, id DESC") of
        {ok, Rows} -> [petring_format:format_notification(Row) || Row <- Rows]
      catch _:_ -> []
      end;
    {error, _} -> []
  end.

-spec mark_read(Ids :: all | [integer()]) -> ok.
mark_read(all) ->
  run("UPDATE notifications SET read = 1 WHERE read = 0", []);
mark_read(Ids) when is_list(Ids) ->
  [run("UPDATE notifications SET read = 1 WHERE id = ?", [Id]) || Id <- Ids],
  ok;
mark_read(_) -> ok.


run(Sql, Args) ->    
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db, Sql, Args) of
        {ok, _} -> ok
      catch _:_ -> ok
      end;
    {error, _} -> ok
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
