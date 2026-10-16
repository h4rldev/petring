-module (petring_db).
-export ([init/0, db/0]).

-spec init() -> ok.
init() ->
  {ok, Db} = errm_sqlite:open(petring_config:get(db_path)),
  {ok, _} = errm_sqlite:exec(Db, "PRAGMA foreign_keys = ON;"),
  errm_http:set_secret(db, Db).

-spec db() -> {ok, reference()} | {error, not_found}.
db() ->
  case errm_http:get_secret(db) of
    {ok, Db} when is_reference(Db) ->
      {ok, Db};
    _ -> {error, not_found}
  end.
        
