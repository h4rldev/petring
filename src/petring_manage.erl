-module (petring_manage).
-export ([get/1, update/1, delete/1, get_ad/1, create_ad/1, update_ad/1, delete_ad/1]).

-spec get(errm_http:request()) -> {ok, errm_http:response()}.
get(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  petring_respond:ok(petring_format:format_user(User), user_order()).

-spec update(errm_http:request()) -> {ok, errm_http:response()}.
update(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  case body_map(Req) of
    {ok, Body} ->
      do_update(User, opt(Body, <<"url">>), opt(Body, <<"contact">>));
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

do_update(User, NewUrl, NewContact) ->
  Username = maps:get("username", User, <<>>),
  OldUrl = maps:get("url", User, <<>>),
  OldContact = maps:get("contact", User, <<>>),
  UrlChanged = NewUrl =/= undefined andalso NewUrl =/= OldUrl,
  ContactChanged = NewContact =/= undefined andalso NewContact =/= OldContact,
  case UrlChanged orelse ContactChanged of
    false ->
      petring_respond:error(304, <<"No changes made">>);
    true ->
      case UrlChanged andalso not petring_filter:url_allowed(<<"user_url">>, NewUrl) of
        true ->
          petring_respond:error(400, <<"Invalid url">>);
        false ->
          FinalUrl = case UrlChanged of true -> NewUrl; false -> OldUrl end,
          FinalContact = case ContactChanged of true -> NewContact; false -> OldContact end,
          apply_update(Username, FinalUrl, FinalContact, UrlChanged)
      end
  end.

apply_update(Username, FinalUrl, FinalContact, UrlChanged) ->
  case petring_db:db() of
    {ok, Db} ->
      try
        {ok, _} = errm_sqlite:exec(Db,
          "UPDATE users SET url = ?, contact = ?, edited_at = ? WHERE username = ?",
          [FinalUrl, FinalContact, erlang:system_time(second), Username]),
        case UrlChanged of
          true ->
            {ok, _} = errm_sqlite:exec(Db,
              "UPDATE ads SET ad_url = ? WHERE username = ?", [FinalUrl, Username]);
          false -> ok
        end,
        {ok, [Row]} = errm_sqlite:query(Db,
          "SELECT * FROM users WHERE username = ? LIMIT 1", [Username]),
        petring_respond:ok(petring_format:format_user(Row), user_order())
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec delete(errm_http:request()) -> {ok, errm_http:response()}.
delete(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  Username = maps:get("username", User, <<>>),
  case petring_db:db() of
    {ok, Db} ->
      try
        {ok, _} = errm_sqlite:exec(Db, "DELETE FROM users WHERE username = ?", [Username]),
        petring_respond:ok(#{<<"message">> => <<"User deleted">>}, [<<"message">>])
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec get_ad(errm_http:request()) -> {ok, errm_http:response()}.
get_ad(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  Username = maps:get("username", User, <<>>),
  case petring_db:db() of
    {ok, Db} ->
      try
        case errm_sqlite:query(Db, "SELECT * FROM ads WHERE username = ? LIMIT 1", [Username]) of
          {ok, [Row]} -> petring_respond:ok(petring_format:format_ad(Row), ad_order());
          {ok, []} -> petring_respond:error(404, <<"Ad not found">>)
        end
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec create_ad(errm_http:request()) -> {ok, errm_http:response()}.
create_ad(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  Username = maps:get("username", User, <<>>),
  UserUrl = maps:get("url", User, <<>>),
  case body_map(Req) of
    {ok, Body} ->
      ImageUrl = maps:get(<<"image_url">>, Body, <<>>),
      do_create_ad(Username, UserUrl, ImageUrl);
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

do_create_ad(_, _, <<>>) ->
  petring_respond:error(400, <<"Invalid image url">>);
do_create_ad(Username, UserUrl, ImageUrl) ->
  case petring_filter:url_allowed(<<"ad_url">>, ImageUrl) of
    false -> petring_respond:error(400, <<"Invalid image url">>);
    true -> insert_ad(Username, UserUrl, ImageUrl)
  end.

insert_ad(Username, UserUrl, ImageUrl) ->
  case petring_db:db() of
    {ok, Db} ->
      try
        case errm_sqlite:query(Db, "SELECT 1 FROM ads WHERE username = ? LIMIT 1", [Username]) of
          {ok, [_ | _]} ->
            petring_respond:error(409, <<"Ad already exists">>);
          {ok, []} ->
            {ok, _} = errm_sqlite:exec(Db,
              "INSERT INTO ads (username, image_url, ad_url, verified, created_at) "
              "VALUES (?, ?, ?, 0, ?)",
              [Username, ImageUrl, UserUrl, erlang:system_time(second)]),
            petring_notifications:record(<<"ad">>, <<"submit">>, Username, ImageUrl, <<>>, <<>>),
            {ok, [Row]} = errm_sqlite:query(Db,
              "SELECT * FROM ads WHERE username = ? LIMIT 1", [Username]),
            petring_respond:ok(petring_format:format_ad(Row), ad_order())
        end
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

-spec update_ad(errm_http:request()) -> {ok, errm_http:response()}.
update_ad(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  Username = maps:get("username", User, <<>>),
  case body_map(Req) of
    {ok, Body} ->
      do_update_ad(Username, opt(Body, <<"image_url">>));
    error ->
      petring_respond:error(400, <<"Invalid JSON body">>)
  end.

do_update_ad(_Username, undefined) ->
  petring_respond:error(304, <<"No changes made">>);
do_update_ad(Username, ImageUrl) ->
  case petring_db:db() of
    {ok, Db} ->
      try
        case errm_sqlite:query(Db, "SELECT * FROM ads WHERE username = ? LIMIT 1", [Username]) of
          {ok, [Row]} ->
            case maps:get("image_url", Row, <<>>) =:= ImageUrl of
              true ->
                petring_respond:error(304, <<"No changes made">>);
              false ->
                case petring_filter:url_allowed(<<"ad_url">>, ImageUrl) of
                  false -> petring_respond:error(400, <<"Invalid image url">>);
                  true -> apply_ad_update(Db, Username, ImageUrl)
                end
            end;
          {ok, []} ->
            petring_respond:error(404, <<"Ad not found">>)
        end
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

apply_ad_update(Db, Username, ImageUrl) ->
  {ok, _} = errm_sqlite:exec(Db,
    "UPDATE ads SET image_url = ?, edited_at = ? WHERE username = ?",
    [ImageUrl, erlang:system_time(second), Username]),
  {ok, [Row]} = errm_sqlite:query(Db, "SELECT * FROM ads WHERE username = ? LIMIT 1", [Username]),
  petring_respond:ok(petring_format:format_ad(Row), ad_order()).

-spec delete_ad(errm_http:request()) -> {ok, errm_http:response()}.
delete_ad(Req) ->
  User = petring_middlewares:get_manage_user(Req),
  Username = maps:get("username", User, <<>>),
  case petring_db:db() of
    {ok, Db} ->
      try
        case errm_sqlite:query(Db, "SELECT 1 FROM ads WHERE username = ? LIMIT 1", [Username]) of
          {ok, [_ | _]} ->
            {ok, _} = errm_sqlite:exec(Db, "DELETE FROM ads WHERE username = ?", [Username]),
            petring_respond:ok(#{<<"message">> => <<"Ad deleted">>}, [<<"message">>]);
          {ok, []} ->
            petring_respond:error(404, <<"Ad not found">>)
        end
      catch _:_ -> petring_respond:error(500, <<"Database error">>)
      end;
    {error, _} ->
      petring_respond:error(500, <<"Database error">>)
  end.

user_order() -> [<<"id">>, <<"username">>, <<"url">>, <<"contact">>, <<"verified">>,
                 <<"created_at">>, <<"edited_at">>, <<"verified_at">>].

ad_order() -> [<<"id">>, <<"username">>, <<"image_url">>, <<"ad_url">>, <<"verified">>,
               <<"created_at">>, <<"edited_at">>, <<"verified_at">>].

opt(Body, Key) ->
  case maps:get(Key, Body, undefined) of
    undefined -> undefined;
    Value -> Value
  end.

body_map(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Map} when is_map(Map) -> {ok, Map};
    _ -> error
  end.
