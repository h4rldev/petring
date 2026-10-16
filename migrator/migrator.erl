-module (migrator).
-export ([main/1]).

main(Args) ->
  case Args of
    ["migrate", DbPath] ->
      migrate(DbPath);
    ["migrate", DbPath, MigrationsDir] ->
      migrate(DbPath, MigrationsDir);
    [_ | _] ->
      io:format("Usage: migrator migrate <db-path> <optionally-migrations-dir>~n")
  end.

migrate(DbPath) ->
  migrate(DbPath, "migrations").

migrate(DbPath, MigrationsDir) ->
  case errm_sqlite:open(DbPath) of
    {ok, Db} ->
      Result = errm_sqlite_migrate:migrate(Db, MigrationsDir),
      errm_sqlite:close(Db),
      Result;
    {error, Reason} ->
      {error, {open_failed, Reason}}
  end.
