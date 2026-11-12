-module(nourish_page).
-behaviour(cowboy_handler).
-export([init/2]).

init(Req0, [Asset]) ->
    Path = filename:join(code:priv_dir(nourish), to_list(Asset)),
    case file:read_file(Path) of
        {ok, Body} ->
            Type = case filename:extension(Path) of
                ".css" -> <<"text/css; charset=utf-8">>;
                ".js" -> <<"application/javascript; charset=utf-8">>;
                _ -> <<"text/html; charset=utf-8">>
            end,
            Req = cowboy_req:reply(200, #{<<"content-type">> => Type}, Body, Req0),
            {ok, Req, undefined};
        {error, _} ->
            Req = cowboy_req:reply(404, #{}, <<"Not found">>, Req0),
            {ok, Req, undefined}
    end.

to_list(Value) when is_binary(Value) -> binary_to_list(Value);
to_list(Value) -> Value.
