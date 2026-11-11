-module(nourish_events).
-behaviour(cowboy_handler).
-export([init/2]).

init(Req0, _Opts) ->
    Req1 = cowboy_req:stream_reply(200, #{<<"content-type">> => <<"text/event-stream">>,
                                          <<"cache-control">> => <<"no-cache">>,
                                          <<"access-control-allow-origin">> => <<"*">>}, Req0),
    ok = nourish_offers:subscribe(),
    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),
    loop(Req1),
    nourish_offers:unsubscribe(),
    {ok, Req1, undefined}.

loop(Req) ->
    receive
        {offer_event, Event} ->
            cowboy_req:stream_body([<<"data: ">>, jsx:encode(Event), <<"\n\n">>], nofin, Req),
            loop(Req)
    after 25000 ->
        cowboy_req:stream_body(<<": keepalive\n\n">>, nofin, Req), loop(Req)
    end.
