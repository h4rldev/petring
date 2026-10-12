-module (petring_newsletter).
-export ([list/1, get/1, feed/1, create/1, update/1, delete/1]).

-define(ORDER, [<<"id">>, <<"slug">>, <<"title">>, <<"content_markdown">>, <<"posted_at">>, <<"edited_at">>]).

-spec list(Req :: errm_http:request()) -> {ok, errm_http:response()}.
list(_Req) ->
  case query("SELECT * FROM newsletter ORDER BY posted_at DESC, id DESC", []) of
    {ok, Rows} -> petring_respond:ok(#{<<"newsletter">> => [petring_format:format_newsletter(R) || R <- Rows]}, [<<"newsletter">>]);
    error -> petring_respond:error(500, <<"Database error">>)
  end.

-spec get(Req :: errm_http:request()) -> {ok, errm_http:response()}.
get(Req) ->
  case find(key_param(Req)) of
    {ok, Row} -> petring_respond:ok(petring_format:format_newsletter(Row), ?ORDER);
    error -> petring_respond:error(404, <<"Newsletter not found">>)
  end.

-spec feed(Req :: errm_http:request()) -> {ok, errm_http:response()}.
feed(_Req) ->
  case query("SELECT * FROM newsletter ORDER BY posted_at DESC, id DESC", []) of
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
                maps:get(<<"content_markdown">>, Body, undefined))
  end.

-spec update(Req :: errm_http:request()) -> {ok, errm_http:response()}.
update(Req) ->
  case body_map(Req) of
    error -> petring_respond:error(400, <<"Invalid body">>);
    {ok, Body} -> do_update(key_param(Req), Body)
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

do_create(Title, Slug, Content) ->
  case valid_entry(Title, Slug, Content) of
    false -> petring_respond:error(400, <<"Invalid newsletter">>);
    true ->
      case run("INSERT INTO newsletter (slug, title, content_markdown, posted_at) VALUES (?, ?, ?, ?)",
               [Slug, Title, Content, now_secs()]) of
        {ok, _} ->
          case latest() of
            {ok, Row} ->
              petring_newsletter_ws:broadcast(<<"created">>, petring_format:format_newsletter(Row)),
              respond_row(Row);
            error -> petring_respond:error(500, <<"Database error">>)
          end;
        {error, Reason} -> insert_error(Reason);
        error -> petring_respond:error(500, <<"Database error">>)
      end
  end.

do_update(Key, Body) ->
  case find(Key) of
    error -> petring_respond:error(404, <<"Newsletter not found">>);
    {ok, Row} ->
      Title = field(Body, <<"title">>, Row, "title"),
      Slug = field(Body, <<"slug">>, Row, "slug"),
      Content = field(Body, <<"content_markdown">>, Row, "content_markdown"),
      case valid_entry(Title, Slug, Content) of
        false -> petring_respond:error(400, <<"Invalid newsletter">>);
        true ->
          Id = maps:get("id", Row),
          case run("UPDATE newsletter SET title = ?, slug = ?, content_markdown = ?, edited_at = ? WHERE id = ?",
                   [Title, Slug, Content, now_secs(), Id]) of
            {ok, _} ->
              case find({id, Id}) of
                {ok, Updated} ->
                  petring_newsletter_ws:broadcast(<<"updated">>, petring_format:format_newsletter(Updated)),
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

valid_entry(Title, Slug, Content) ->
  nonempty(Title) andalso nonempty(Slug) andalso nonempty(Content).

nonempty(B) when is_binary(B) -> B =/= <<>>;
nonempty(_) -> false.

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
