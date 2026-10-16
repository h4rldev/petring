-module (petring_newsletter).
-export ([list/1, list_all/1, get/1, feed/1, create/1, update/1, delete/1]).

-define(ORDER, [<<"id">>, <<"slug">>, <<"title">>, <<"content_markdown">>, <<"status">>, <<"authors">>, <<"posted_at">>, <<"edited_at">>]).

-spec list(Req :: errm_http:request()) -> {ok, errm_http:response()}.
list(_Req) ->
  case query("SELECT * FROM newsletter WHERE status = 'published' AND posted_at <= ? ORDER BY posted_at DESC, id DESC", [now_secs()]) of
    {ok, Rows} -> petring_respond:ok(#{<<"newsletter">> => [petring_format:format_newsletter(R) || R <- Rows]}, [<<"newsletter">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec list_all(Req :: errm_http:request()) -> {ok, errm_http:response()}.
list_all(_Req) ->
  case query("SELECT * FROM newsletter ORDER BY posted_at DESC, id DESC", []) of
    {ok, Rows} -> petring_respond:ok(#{<<"newsletter">> => [petring_format:format_newsletter(R) || R <- Rows]}, [<<"newsletter">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec get(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get(Req) ->
  case find(key_param(Req)) of
    {ok, Row} ->
      case visible(Row) of
        true -> petring_respond:ok(petring_format:format_newsletter(Row), ?ORDER);
        false -> petring_respond:error(404, <<"Newsletter not found">>)
      end;
    error -> petring_respond:error(404, <<"Newsletter not found">>)
  end.

-spec feed(Req :: errm_http:request()) -> {ok, errm_http:response()}.
feed(_Req) ->
  case query("SELECT * FROM newsletter WHERE status = 'published' AND posted_at <= ? ORDER BY posted_at DESC, id DESC", [now_secs()]) of
    {ok, Rows} ->
      Site = petring_config:get(server_url),
      Body = iolist_to_binary(render_feed(Rows, Site)),
      {ok, {200, #{<<"content-type">> => <<"application/rss+xml; charset=utf-8">>}, Body}};
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec create(Req :: errm_http:request()) -> {ok, errm_http:response()}.
create(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid body">>);
    {ok, Body} ->
      do_create(maps:get(<<"title">>, Body, undefined),
                maps:get(<<"slug">>, Body, undefined),
                maps:get(<<"content_markdown">>, Body, undefined),
                maps:get(<<"status">>, Body, <<"published">>),
                maps:get(<<"posted_at">>, Body, undefined), actor(Req))
  end.

-spec update(Req :: errm_http:request()) -> {ok, errm_http:response()}.
update(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid body">>);
    {ok, Body} -> do_update(key_param(Req), Body, actor(Req))
  end.

-spec delete(Req :: errm_http:request()) -> {ok, errm_http:response()}.
delete(Req) ->
  case find(key_param(Req)) of
    error -> petring_respond:error(404, <<"Newsletter not found">>);
    {ok, Row} ->
      case run("DELETE FROM newsletter WHERE id = ?", [maps:get("id", Row)]) of
        {ok, _} ->
          petring_newsletter_ws:broadcast(<<"deleted">>, petring_format:format_newsletter(Row)),
          petring_respond:ok(#{<<"message">> => <<"Newsletter deleted">>}, [<<"message">>]);
        error -> petring_respond:error(500, <<"Database error">>)
      end
  end.

do_create(Title, Slug, Content, Status, PostedAt, Actor) ->
  case valid_entry(Title, Slug, Content, Status) of
    false -> petring_respond:error(400, <<"Invalid newsletter">>);
    true ->
      case run("INSERT INTO newsletter (slug, title, content_markdown, status, posted_at, authors) VALUES (?, ?, ?, ?, ?, ?)",
               [Slug, Title, Content, Status, pub_time(PostedAt), errm_json:encode(add_author([], Actor))]) of
        {ok, _} ->
          case latest() of
            {ok, Row} ->
              maybe_broadcast(<<"created">>, Row),
              respond_row(Row);
            error -> petring_respond:error(500, <<"Database error">>)
          end;
        {error, Reason} -> insert_error(Reason);
        error -> petring_respond:error(500, <<"Database error">>)
      end
  end.

do_update(Key, Body, Actor) ->
  case find(Key) of
    error -> petring_respond:error(404, <<"Newsletter not found">>);
    {ok, Row} ->
      Title = field(Body, <<"title">>, Row, "title"),
      Slug = field(Body, <<"slug">>, Row, "slug"),
      Content = field(Body, <<"content_markdown">>, Row, "content_markdown"),
      Status = field(Body, <<"status">>, Row, "status"),
      Authors = errm_json:encode(add_author(authors(Row), Actor)),
      Posted = case maps:get(<<"posted_at">>, Body, undefined) of
                 undefined -> maps:get("posted_at", Row, now_secs());
                 Value -> pub_time(Value)
               end,
      case valid_entry(Title, Slug, Content, Status) of
        false -> petring_respond:error(400, <<"Invalid newsletter">>);
        true ->
          Id = maps:get("id", Row),
          case run("UPDATE newsletter SET title = ?, slug = ?, content_markdown = ?, status = ?, posted_at = ?, edited_at = ?, authors = ? WHERE id = ?",
                   [Title, Slug, Content, Status, Posted, now_secs(), Authors, Id]) of
            {ok, _} ->
              case find({id, Id}) of
                {ok, Updated} ->
                  maybe_broadcast(<<"updated">>, Updated),
                  respond_row(Updated);
                error -> petring_respond:error(500, <<"Database error">>)
              end;
            {error, Reason} -> insert_error(Reason);
            error -> petring_respond:error(500, <<"Database error">>)
          end
      end
  end.

insert_error(Reason) ->
  case duplicate_slug(Reason) of
    true -> petring_respond:error(409, <<"Slug already exists">>);
    false -> petring_respond:error(500, <<"Database error">>)
  end.

respond_row(Row) ->
  petring_respond:ok(petring_format:format_newsletter(Row), ?ORDER).

visible(Row) ->
  maps:get("status", Row, <<"published">>) =:= <<"published">>
    andalso maps:get("posted_at", Row, 0) =< now_secs().

maybe_broadcast(Action, Row) ->
  case visible(Row) of
    true -> petring_newsletter_ws:broadcast(Action, petring_format:format_newsletter(Row));
    false -> ok
  end.

pub_time(Value) when is_integer(Value) -> Value;
pub_time(_) -> now_secs().

valid_entry(Title, Slug, Content, Status) ->
  nonempty(Title) andalso nonempty(Slug) andalso nonempty(Content) andalso valid_status(Status).

valid_status(<<"draft">>) -> true;
valid_status(<<"published">>) -> true;
valid_status(_) -> false.

nonempty(B) when is_binary(B) -> B =/= <<>>;
nonempty(_) -> false.

actor(Req) ->
  case petring_middlewares:get_claims(Req) of
    Claims when is_map(Claims) -> maps:get(<<"sub">>, Claims, <<>>);
    _ -> <<>>
  end.

authors(Row) ->
  case errm_json:decode(maps:get("authors", Row, <<"[]">>)) of
    {ok, List} when is_list(List) -> List;
    _ -> []
  end.

add_author(Current, <<>>) -> Current;
add_author(Current, Actor) ->
  case lists:member(Actor, Current) of
    true -> Current;
    false -> Current ++ [Actor]
  end.

field(Body, Key, Row, DKey) ->
  case maps:get(Key, Body, undefined) of
    undefined -> maps:get(DKey, Row, <<>>);
    Value -> Value
  end.

find({id, Id}) -> one("SELECT * FROM newsletter WHERE id = ? LIMIT 1", [Id]);
find(Key) ->
  case identifier(Key) of
    {id, Id} -> one("SELECT * FROM newsletter WHERE id = ? LIMIT 1", [Id]);
    {slug, Slug} -> one("SELECT * FROM newsletter WHERE slug = ? LIMIT 1", [Slug])
  end.

one(Sql, Args) ->
  case query(Sql, Args) of
    {ok, [Row | _]} -> {ok, Row};
    _ -> error
  end.

latest() -> one("SELECT * FROM newsletter ORDER BY id DESC LIMIT 1", []).

identifier(Bin) when is_binary(Bin) ->
  case (catch binary_to_integer(Bin)) of
    Id when is_integer(Id) -> {id, Id};
    _ -> {slug, Bin}
  end.

duplicate_slug(Reason) when is_binary(Reason) ->
  binary:match(Reason, <<"UNIQUE constraint failed: newsletter.slug">>) =/= nomatch;
duplicate_slug(Reason) when is_list(Reason) ->
  duplicate_slug(list_to_binary(Reason));
duplicate_slug(_) -> false.

render_feed(Rows, Site) ->
  [<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n">>,
   <<"<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\">\n">>,
   <<"<channel>\n">>,
   xml_tag("title", petring_config:get(server_name)),
   xml_tag("link", Site),
   xml_tag("description", petring_config:get(server_name)),
   [<<"<atom:link href=\"">>, Site, <<"/newsletter/feed.xml\" rel=\"self\" type=\"application/rss+xml\"/>\n">>],
   [feed_item(Row, Site) || Row <- Rows],
   <<"</channel>\n</rss>\n">>].

feed_item(Row, Site) ->
  Link = Site ++ "/newsletter/" ++ binary_to_list(to_bin(maps:get("slug", Row, <<>>))),
  [<<"<item>\n">>,
   xml_tag("title", maps:get("title", Row, <<>>)),
   xml_tag("link", Link),
   [<<"<guid isPermaLink=\"true\">">>, esc(Link), <<"</guid>\n">>],
   [<<"<pubDate>">>, pub_date(maps:get("posted_at", Row, undefined)), <<"</pubDate>\n">>],
   xml_tag("content:encoded", content_html(Row)),
   <<"</item>\n">>].

content_html(Row) ->
  case to_bin(maps:get("content_markdown", Row, <<>>)) of
    <<>> -> <<>>;
    Markdown -> markdown_to_html(Markdown)
  end.

markdown_to_html(Markdown) ->
  try errm_cmark_gfm_nif:to_html(Markdown) of
    {ok, Html} -> Html;
    {error, _} -> Markdown
  catch _:_ -> Markdown
  end.

pub_date(Secs) when is_integer(Secs) ->
  {{Year, Month, Day}, {Hour, Minute, Second}} = calendar:system_time_to_universal_time(Secs, second),
  Weekday = lists:nth(calendar:day_of_the_week(Year, Month, Day),
    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]),
  MonthName = lists:nth(Month,
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]),
  io_lib:format("~s, ~2..0B ~s ~4..0B ~2..0B:~2..0B:~2..0B +0000",
    [Weekday, Day, MonthName, Year, Hour, Minute, Second]);
pub_date(_) -> [].

xml_tag(Name, Value) ->
  [<<"<">>, Name, <<">">>, esc(Value), <<"</">>, Name, <<">\n">>].

esc(Value) ->
  iolist_to_binary(escape(to_bin(Value))).

escape(<<>>) -> [];
escape(<<Char, Rest/binary>>) ->
  Escaped = case Char of
    $& -> <<"&amp;">>;
    $< -> <<"&lt;">>;
    $> -> <<"&gt;">>;
    $" -> <<"&quot;">>;
    $' -> <<"&apos;">>;
    _ -> <<Char>>
  end,
  [Escaped | escape(Rest)].

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L);
to_bin(_) -> <<>>.

key_param(Req) -> maps:get(<<"id">>, maps:get(params, Req, #{}), <<>>).

body_map(Req) ->
  case errm_json:decode(maps:get(body, Req, <<>>)) of
    {ok, Map} when is_map(Map) -> {ok, Map};
    _ -> error
  end.

query(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:query(Db, Sql, Args) of
        {ok, Rows} -> {ok, Rows};
        _ -> error
      catch _:_ -> error
      end;
    {error, _} -> error
  end.

run(Sql, Args) ->
  case petring_db:db() of
    {ok, Db} ->
      try errm_sqlite:exec(Db, Sql, Args) of
        {ok, Changes} -> {ok, Changes}
      catch _:{error, Reason} -> {error, Reason};
            _:_ -> error
      end;
    {error, _} -> error
  end.

now_secs() -> erlang:system_time(second).
