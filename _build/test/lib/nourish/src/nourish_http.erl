-module(nourish_http).
-behaviour(cowboy_handler).
-export([init/2]).

init(Req0, [Route]) ->
    Method = cowboy_req:method(Req0),
    {Status, Body, Req1} = handle(Route, Method, Req0),
    Req2 = cowboy_req:reply(Status, #{<<"content-type">> => <<"application/json; charset=utf-8">>,
                                      <<"access-control-allow-origin">> => <<"*">>},
                            jsx:encode(Body), Req1),
    {ok, Req2, undefined}.

handle(offers, <<"GET">>, Req) ->
    {ok, Offers} = nourish_offers:list(), {200, Offers, Req};
handle(offers, <<"POST">>, Req0) ->
    {Data, Req} = read_json(Req0),
    case validate_offer(Data) of
        {ok, Offer} -> {ok, Created} = nourish_offers:create(Offer), {201, Created, Req};
        {error, Why} -> {400, #{error => Why}, Req}
    end;
handle(impact, <<"GET">>, Req) ->
    {ok, Impact} = nourish_offers:impact(), {200, Impact, Req};
handle(offer_action, <<"POST">>, Req0) ->
    Id = cowboy_req:binding(id, Req0), Action = cowboy_req:binding(action, Req0),
    {Data, Req} = read_json(Req0),
    Result = case Action of
        <<"claim">> -> nourish_offers:claim(Id, maps:get(<<"recipient">>, Data, <<"Community recipient">>));
        <<"collect">> -> nourish_offers:collect(Id, maps:get(<<"quantity">>, Data, 0));
        <<"cancel">> -> nourish_offers:cancel(Id);
        _ -> {error, bad_request}
    end,
    case Result of
        {ok, Offer} -> {200, Offer, Req};
        {error, Why} -> {case Why of not_found -> 404; _ -> 409 end, #{error => Why}, Req}
    end;
handle(_Route, _Method, Req) -> {405, #{error => method_not_allowed}, Req}.

read_json(Req0) ->
    case cowboy_req:read_body(Req0) of
        {ok, <<>>, Req} -> {#{}, Req};
        {ok, Body, Req} -> {jsx:decode(Body, [return_maps]), Req};
        {more, _Body, Req} -> {#{}, Req}
    end.

validate_offer(Data) when is_map(Data) ->
    Required = [<<"business">>, <<"title">>, <<"quantity">>, <<"unit">>,
                <<"pickup_by">>, <<"address">>, <<"kind">>],
    case lists:all(fun(K) -> maps:is_key(K, Data) end, Required) of
        false -> {error, missing_fields};
        true ->
            try
                Qty = maps:get(<<"quantity">>, Data),
                Kind = maps:get(<<"kind">>, Data),
                _ = calendar:rfc3339_to_system_time(binary_to_list(maps:get(<<"pickup_by">>, Data)), [{unit, second}]),
                case is_number(Qty) andalso Qty > 0 andalso
                     lists:member(Kind, [<<"donation">>, <<"discount">>]) of
                    true -> {ok, normalize_offer(Data)};
                    false -> {error, invalid_quantity_or_kind}
                end
            catch _:_ -> {error, invalid_pickup_by}
            end
    end;
validate_offer(_) -> {error, invalid_payload}.

normalize_offer(Data) ->
    maps:from_list([{key(K), V} || {K, V} <- maps:to_list(Data)]).
key(<<"business">>) -> business;
key(<<"title">>) -> title;
key(<<"quantity">>) -> quantity;
key(<<"unit">>) -> unit;
key(<<"pickup_by">>) -> pickup_by;
key(<<"address">>) -> address;
key(<<"kind">>) -> kind;
key(<<"price">>) -> price;
key(<<"notes">>) -> notes.
