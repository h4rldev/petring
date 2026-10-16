-module (petring_respond).
-compile({no_auto_import, [error/2]}).
-export ([ok/1, ok/2, error/2, redirect/1, html/1, error_handlers/0]).

-spec ok(Body :: map()) -> {ok, errm_http:response()}.
ok(Body) ->
  ok(Body, []).

-spec ok(Body :: map(), Order :: [binary() | atom()]) -> {ok, errm_http:response()}.
ok(Body, Order) ->
  json(200, Body, Order).

-spec error(Status :: integer(), Message :: binary() | string()) -> {ok, errm_http:response()}.
error(Status, Message) ->
  json(Status, #{<<"status">> => Status, <<"message">> => to_bin(Message)},
       [<<"status">>, <<"message">>]).

-spec redirect(Url :: binary() | string()) -> {ok, errm_http:response()}.
redirect(Url) ->
  {ok, {307, #{<<"location">> => to_bin(Url)}, <<>>}}.

-spec html(Body :: iodata()) -> {ok, errm_http:response()}.
html(Body) ->
  {ok, {200, #{<<"content-type">> => <<"text/html; charset=utf-8">>}, Body}}.

-spec error_handlers() -> errm_http:error_handler_map().
error_handlers() ->
  #{
    not_found => fun(Req) -> error(404, not_found_message(Req)) end,
    method_not_allowed => fun(_) -> error(405, <<"Method not allowed.">>) end,
    internal_error => fun(_) -> error(500, <<"Internal server error.">>) end,
    bad_request => fun(_) -> error(400, <<"Bad request.">>) end,
    request_entity_too_large => fun(_) -> error(413, <<"Request entity too large.">>) end
  }.

not_found_message(Req) ->
  Path = maps:get(raw_path, Req, <<"/">>),
  <<"The requested resource at ", Path/binary, " could not be found.">>.

json(Status, Body, Order) ->
  Headers = #{<<"content-type">> => <<"application/json">>},
  {ok, {Status, Headers, errm_json:to_binary(Body, #{order => Order})}}.

to_bin(B) when is_binary(B) -> B;
to_bin(L) when is_list(L) -> list_to_binary(L).

