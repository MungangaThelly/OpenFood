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
        <<"claim">> -> nourish_offers:claim(Id,
            maps:get(<<"recipient">>, Data, <<"Community recipient">>),
            maps:get(<<"actor">>, Data, <<"Demo user">>));
        <<"collect">> -> nourish_offers:collect(Id, normalize_handoff(Data));
        <<"cancel">> -> nourish_offers:cancel(Id, maps:get(<<"actor">>, Data, <<"Demo user">>));
        <<"issue">> -> nourish_offers:report_issue(Id,
            maps:get(<<"actor">>, Data, <<"Demo user">>),
            maps:get(<<"reason">>, Data, <<>>));
        <<"resolve">> -> nourish_offers:resolve_issue(Id,
            maps:get(<<"actor">>, Data, <<"Demo coordinator">>),
            maps:get(<<"resolution">>, Data, <<>>));
        <<"audit">> -> nourish_offers:audit(Id);
        _ -> {error, bad_request}
    end,
    case Result of
        {ok, Value} -> {200, Value, Req};
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
    Required = [<<"business">>, <<"posted_by">>, <<"title">>, <<"quantity">>, <<"unit">>,
                <<"pickup_by">>, <<"address">>, <<"kind">>, <<"date_type">>,
                <<"handling">>, <<"donor_contact">>, <<"batch_reference">>,
                <<"donor_safety_confirmed">>],
    case lists:all(fun(K) -> maps:is_key(K, Data) end, Required) of
        false -> {error, missing_fields};
        true ->
            try
                Qty = maps:get(<<"quantity">>, Data),
                Kind = maps:get(<<"kind">>, Data),
                Price = maps:get(<<"price">>, Data, 0),
                DateType = maps:get(<<"date_type">>, Data),
                true = maps:get(<<"donor_safety_confirmed">>, Data),
                _ = calendar:rfc3339_to_system_time(binary_to_list(maps:get(<<"pickup_by">>, Data)), [{unit, second}]),
                case is_number(Qty) andalso Qty > 0 andalso
                     is_number(Price) andalso Price >= 0 andalso
                     (Kind =/= <<"donation">> orelse Price =:= 0) andalso
                     lists:member(Kind, [<<"donation">>, <<"discount">>]) andalso
                     lists:member(DateType, [<<"best_before">>, <<"use_by">>, <<"not_applicable">>]) andalso
                     (DateType =:= <<"not_applicable">> orelse
                      nonempty(maps:get(<<"date_value">>, Data, <<>>))) andalso
                     valid_food_date(DateType, maps:get(<<"date_value">>, Data, <<>>),
                                     maps:get(<<"pickup_by">>, Data)) andalso
                     nonempty(maps:get(<<"handling">>, Data)) andalso
                     nonempty(maps:get(<<"business">>, Data)) andalso
                     nonempty(maps:get(<<"posted_by">>, Data)) andalso
                     nonempty(maps:get(<<"donor_contact">>, Data)) andalso
                     nonempty(maps:get(<<"batch_reference">>, Data)) of
                    true -> {ok, normalize_offer(Data)};
                    false -> {error, invalid_offer_fields}
                end
            catch _:_ -> {error, invalid_offer_fields}
            end
    end;
validate_offer(_) -> {error, invalid_payload}.

normalize_offer(Data) ->
    maps:from_list([{key(K), V} || {K, V} <- maps:to_list(Data)]).
key(<<"business">>) -> business;
key(<<"posted_by">>) -> posted_by;
key(<<"title">>) -> title;
key(<<"quantity">>) -> quantity;
key(<<"unit">>) -> unit;
key(<<"pickup_by">>) -> pickup_by;
key(<<"address">>) -> address;
key(<<"kind">>) -> kind;
key(<<"price">>) -> price;
key(<<"notes">>) -> notes;
key(<<"date_type">>) -> date_type;
key(<<"date_value">>) -> date_value;
key(<<"handling">>) -> handling;
key(<<"storage_temperature">>) -> storage_temperature;
key(<<"allergens">>) -> allergens;
key(<<"ingredients">>) -> ingredients;
key(<<"donor_contact">>) -> donor_contact;
key(<<"batch_reference">>) -> batch_reference;
key(<<"donor_safety_confirmed">>) -> donor_safety_confirmed.

normalize_handoff(Data) ->
    maps:filter(fun(_Key, Value) -> Value =/= undefined end,
        #{quantity => maps:get(<<"quantity">>, Data, 0),
          confirmed_by => maps:get(<<"confirmed_by">>, Data, <<>>),
          package_intact => maps:get(<<"package_intact">>, Data, false),
          date_checked => maps:get(<<"date_checked">>, Data, false),
          temperature_c => maps:get(<<"temperature_c">>, Data, undefined),
          condition_notes => maps:get(<<"condition_notes">>, Data, <<>>)}).

nonempty(Value) when is_binary(Value) -> byte_size(string:trim(Value)) > 0;
nonempty(_) -> false.

valid_food_date(<<"not_applicable">>, _Date, _PickupBy) -> true;
valid_food_date(DateType, Date, PickupBy) ->
    case string:tokens(binary_to_list(Date), "-") of
        [Year, Month, Day] ->
            Y = list_to_integer(Year), M = list_to_integer(Month), D = list_to_integer(Day),
            calendar:valid_date({Y, M, D}) andalso
            (DateType =/= <<"use_by">> orelse
             binary_to_list(Date) >= binary_to_list(binary:part(PickupBy, 0, 10)));
        _ -> false
    end.
