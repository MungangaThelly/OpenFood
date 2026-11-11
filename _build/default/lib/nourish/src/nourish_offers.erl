-module(nourish_offers).
-behaviour(gen_server).

-export([start_link/0, create/1, list/0, claim/2, collect/2, cancel/1, impact/0,
         subscribe/0, unsubscribe/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(GROUP, nourish_offer_updates).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
create(Offer) -> gen_server:call(?MODULE, {create, Offer}).
list() -> gen_server:call(?MODULE, list).
claim(Id, Recipient) -> gen_server:call(?MODULE, {claim, Id, Recipient}).
collect(Id, Quantity) -> gen_server:call(?MODULE, {collect, Id, Quantity}).
cancel(Id) -> gen_server:call(?MODULE, {cancel, Id}).
impact() -> gen_server:call(?MODULE, impact).
subscribe() -> pg:join(?GROUP, self()).
unsubscribe() -> pg:leave(?GROUP, self()).

init([]) ->
    _ = pg:start_link(),
    {ok, #{offers => #{}}}.

handle_call({create, Offer0}, _From, State = #{offers := Offers}) ->
    Id = integer_to_binary(erlang:unique_integer([positive, monotonic])),
    Offer = Offer0#{id => Id, status => available, created_at => now_iso()},
    New = State#{offers := Offers#{Id => Offer}},
    broadcast(#{type => offer_created, offer => Offer}),
    {reply, {ok, Offer}, New};
handle_call(list, _From, State = #{offers := Offers}) ->
    Current = [O || O <- maps:values(Offers), maps:get(status, O) =:= available,
                        not expired(O)],
    {reply, {ok, Current}, State};
handle_call({claim, Id, Recipient}, _From, State) ->
    transition(Id, State, fun(O) ->
        case {maps:get(status, O), expired(O)} of
            {available, false} -> {ok, O#{status => claimed, recipient => Recipient,
                                           claimed_at => now_iso()}};
            {available, true} -> {error, expired};
            _ -> {error, unavailable}
        end
    end);
handle_call({collect, Id, Quantity}, _From, State) ->
    transition(Id, State, fun(O) ->
        case maps:get(status, O) of
            claimed ->
                case is_number(Quantity) andalso Quantity > 0 andalso
                     Quantity =< maps:get(quantity, O) of
                    true -> {ok, O#{status => collected, collected_quantity => Quantity,
                                    collected_at => now_iso()}};
                    false -> {error, invalid_quantity}
                end;
            _ -> {error, not_claimed}
        end
    end);
handle_call({cancel, Id}, _From, State) ->
    transition(Id, State, fun(O) ->
        case lists:member(maps:get(status, O), [available, claimed]) of
            true -> {ok, O#{status => cancelled, cancelled_at => now_iso()}};
            false -> {error, unavailable}
        end
    end);
handle_call(impact, _From, State = #{offers := Offers}) ->
    Collected = [O || O <- maps:values(Offers), maps:get(status, O) =:= collected],
    Totals = lists:foldl(fun(O, Acc) ->
        Unit = maps:get(unit, O), Qty = maps:get(collected_quantity, O),
        Acc#{Unit => maps:get(Unit, Acc, 0) + Qty}
    end, #{}, Collected),
    {reply, {ok, #{completed_pickups => length(Collected), quantities_by_unit => Totals}}, State};
handle_call(_Request, _From, State) -> {reply, {error, bad_request}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

offer_lifecycle_test_() ->
    {setup,
     fun() ->
         {ok, Pid} = start_link(),
         Pid
     end,
     fun(Pid) -> gen_server:stop(Pid) end,
     fun(_Pid) ->
         {timeout, 5, fun() ->
             {ok, Created} = create(test_offer()),
             Id = maps:get(id, Created),
             Parent = self(),
             Claim = fun(Recipient) ->
                 Parent ! {claim_result, claim(Id, Recipient)}
             end,
             _ = spawn(fun() -> Claim(<<"Pantry A">>) end),
             _ = spawn(fun() -> Claim(<<"Pantry B">>) end),
             First = receive {claim_result, Result1} -> Result1 end,
             Second = receive {claim_result, Result2} -> Result2 end,
             Results = [First, Second],
             ?assertEqual(1, length([ok || {ok, _} <- Results])),
             ?assertEqual(1, length([error || {error, unavailable} <- Results])),
             ?assertEqual({error, invalid_quantity}, collect(Id, 0)),
             {ok, _} = collect(Id, 3),
             {ok, #{completed_pickups := 1,
                    quantities_by_unit := #{<<"boxes">> := 3}}} = impact()
         end}
     end}.

test_offer() ->
    #{business => <<"Test Market">>, title => <<"Produce box">>, quantity => 5,
      unit => <<"boxes">>, pickup_by => <<"2099-01-01T18:00:00Z">>,
      address => <<"1 Test Street">>, kind => <<"donation">>}.
-endif.

transition(Id, State = #{offers := Offers}, Fun) ->
    case maps:find(Id, Offers) of
        error -> {reply, {error, not_found}, State};
        {ok, Offer} ->
            case Fun(Offer) of
                {error, Why} -> {reply, {error, Why}, State};
                {ok, Updated} ->
                    broadcast(#{type => offer_updated, offer => Updated}),
                    {reply, {ok, Updated}, State#{offers := Offers#{Id => Updated}}}
            end
    end.

broadcast(Event) -> lists:foreach(fun(Pid) -> Pid ! {offer_event, Event} end,
                                  pg:get_members(?GROUP)).

expired(Offer) ->
    case calendar:rfc3339_to_system_time(binary_to_list(maps:get(pickup_by, Offer)), [{unit, second}]) of
        Deadline -> Deadline =< erlang:system_time(second)
    end.

now_iso() -> list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second),
                                                            [{unit, second}, {offset, "Z"}])).
