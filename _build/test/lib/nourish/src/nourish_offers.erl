-module(nourish_offers).
-behaviour(gen_server).

-export([start_link/0, create/1, list/0, claim/2, claim/3, collect/2, report_issue/3,
         resolve_issue/3, cancel/1, cancel/2, impact/0, audit/1, subscribe/0, unsubscribe/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-define(GROUP, nourish_offer_updates).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
create(Offer) -> gen_server:call(?MODULE, {create, Offer}).
list() -> gen_server:call(?MODULE, list).
claim(Id, Recipient) -> gen_server:call(?MODULE, {claim, Id, Recipient, Recipient}).
claim(Id, Recipient, Actor) -> gen_server:call(?MODULE, {claim, Id, Recipient, Actor}).
collect(Id, Handoff) -> gen_server:call(?MODULE, {collect, Id, Handoff}).
report_issue(Id, Actor, Reason) -> gen_server:call(?MODULE, {report_issue, Id, Actor, Reason}).
resolve_issue(Id, Actor, Resolution) -> gen_server:call(?MODULE, {resolve_issue, Id, Actor, Resolution}).
cancel(Id) -> cancel(Id, <<"Demo user">>).
cancel(Id, Actor) -> gen_server:call(?MODULE, {cancel, Id, Actor}).
impact() -> gen_server:call(?MODULE, impact).
audit(Id) -> gen_server:call(?MODULE, {audit, Id}).
subscribe() -> pg:join(?GROUP, self()).
unsubscribe() -> pg:leave(?GROUP, self()).

init([]) ->
    _ = pg:start_link(),
    {ok, #{offers => #{}, audit => []}}.

handle_call({create, Offer0}, _From, State = #{offers := Offers, audit := Audit}) ->
    Id = integer_to_binary(erlang:unique_integer([positive, monotonic])),
    Offer = Offer0#{id => Id, status => available, created_at => now_iso()},
    NewAudit = append_audit(Audit, Id, created, maps:get(posted_by, Offer), #{status => available}),
    NewState = State#{offers := Offers#{Id => Offer}, audit := NewAudit},
    broadcast(#{type => offer_created, offer => Offer}),
    {reply, {ok, Offer}, NewState};
handle_call(list, _From, State0) ->
    State = expire_offers(State0),
    Offers = maps:get(offers, State),
    {reply, {ok, maps:values(Offers)}, State};
handle_call({claim, Id, Recipient, Actor}, _From, State) ->
    transition(Id, State, fun(O) ->
        case {maps:get(status, O), expired(O)} of
            {available, false} -> {ok, O#{status => claimed, recipient => Recipient,
                                           claimed_by => Actor, claimed_at => now_iso()}};
            {available, true} -> {error, expired};
            _ -> {error, unavailable}
        end
    end);
handle_call({collect, Id, Handoff}, _From, State) ->
    transition(Id, State, fun(O) ->
        case maps:get(status, O) of
            claimed ->
                Quantity = maps:get(quantity, Handoff, 0),
                Valid = is_number(Quantity) andalso Quantity > 0 andalso
                        Quantity =< maps:get(quantity, O) andalso
                        maps:get(package_intact, Handoff, false) =:= true andalso
                        maps:get(date_checked, Handoff, false) =:= true andalso
                        nonempty(maps:get(confirmed_by, Handoff, <<>>)),
                case Valid of
                    true -> {ok, O#{status => collected, collected_quantity => Quantity,
                                    collected_at => now_iso(), handoff => Handoff}};
                    false -> {error, invalid_handoff}
                end;
            _ -> {error, not_claimed}
        end
    end);
handle_call({report_issue, Id, Actor, Reason}, _From, State) ->
    transition(Id, State, fun(O) ->
        case lists:member(maps:get(status, O), [claimed, collected]) andalso nonempty(Reason) of
            true -> {ok, O#{status => exception, exception => #{actor => Actor, reason => Reason,
                                                                  reported_at => now_iso()}}};
            false -> {error, invalid_exception}
        end
    end);
handle_call({resolve_issue, Id, Actor, Resolution}, _From, State) ->
    transition(Id, State, fun(O) ->
        case maps:get(status, O) =:= exception andalso nonempty(Resolution) of
            true -> {ok, O#{status => resolved, resolution => #{actor => Actor, note => Resolution,
                                                                 resolved_at => now_iso()}}};
            false -> {error, no_open_exception}
        end
    end);
handle_call({cancel, Id, Actor}, _From, State) ->
    transition(Id, State, fun(O) ->
        case lists:member(maps:get(status, O), [available, claimed]) of
            true -> {ok, O#{status => cancelled, cancelled_by => Actor, cancelled_at => now_iso()}};
            false -> {error, unavailable}
        end
    end);
handle_call(impact, _From, State = #{offers := Offers}) ->
    Collected = [O || O <- maps:values(Offers), maps:is_key(collected_at, O)],
    Totals = lists:foldl(fun(O, Acc) ->
        Unit = maps:get(unit, O), Qty = maps:get(collected_quantity, O),
        Acc#{Unit => maps:get(Unit, Acc, 0) + Qty}
    end, #{}, Collected),
    {reply, {ok, #{completed_pickups => length(Collected), quantities_by_unit => Totals}}, State};
handle_call({audit, Id}, _From, State = #{audit := Audit}) ->
    Events = [E || E <- Audit, maps:get(offer_id, E) =:= Id],
    {reply, {ok, Events}, State};
handle_call(_Request, _From, State) -> {reply, {error, bad_request}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

offer_lifecycle_test_() ->
    {setup,
     fun() -> {ok, Pid} = start_link(), Pid end,
     fun(Pid) -> gen_server:stop(Pid) end,
     fun(_Pid) ->
         {timeout, 5, fun() ->
             {ok, Created} = create(test_offer()),
             Id = maps:get(id, Created),
             Parent = self(),
             Claim = fun(Recipient) -> Parent ! {claim_result, claim(Id, Recipient)} end,
             _ = spawn(fun() -> Claim(<<"Pantry A">>) end),
             _ = spawn(fun() -> Claim(<<"Pantry B">>) end),
             First = receive {claim_result, Result1} -> Result1 end,
             Second = receive {claim_result, Result2} -> Result2 end,
             Results = [First, Second],
             ?assertEqual(1, length([ok || {ok, _} <- Results])),
             ?assertEqual(1, length([error || {error, unavailable} <- Results])),
             ?assertEqual({error, invalid_handoff}, collect(Id, #{})),
             Handoff = #{quantity => 3, confirmed_by => <<"Volunteer A">>,
                         package_intact => true, date_checked => true,
                         temperature_c => 4, condition_notes => <<"Chilled and intact">>},
             {ok, _} = collect(Id, Handoff),
             {ok, #{completed_pickups := 1,
                    quantities_by_unit := #{<<"boxes">> := 3}}} = impact(),
             {ok, Audit} = audit(Id),
             ?assertEqual([created, claimed, collected], [maps:get(action, E) || E <- Audit]),
             CollectedEvent = lists:nth(3, Audit),
             HandoffDetail = maps:get(handoff, maps:get(details, CollectedEvent)),
             ?assertEqual(true, maps:get(package_intact, HandoffDetail)),
             ?assertEqual(4, maps:get(temperature_c, HandoffDetail))
         end}
     end}.

exception_audit_test_() ->
    {setup,
     fun() -> {ok, Pid} = start_link(), Pid end,
     fun(Pid) -> gen_server:stop(Pid) end,
     fun(_Pid) ->
         {ok, Created} = create(test_offer()), Id = maps:get(id, Created),
         {ok, _} = claim(Id, <<"Pantry A">>, <<"Coordinator">>),
         {ok, _} = report_issue(Id, <<"Volunteer">>, <<"Seal damaged">>),
         {ok, _} = resolve_issue(Id, <<"Coordinator">>, <<"Offer withdrawn">>),
         {ok, Audit} = audit(Id),
         ?_assertEqual([created, claimed, exception_reported, exception_resolved],
                       [maps:get(action, E) || E <- Audit])
     end}.

test_offer() ->
    #{business => <<"Test Market">>, title => <<"Produce box">>, quantity => 5,
      unit => <<"boxes">>, pickup_by => <<"2099-01-01T18:00:00Z">>,
      address => <<"1 Test Street">>, kind => <<"donation">>, posted_by => <<"Store staff">>}.

expiry_audit_test_() ->
    {setup,
     fun() -> {ok, Pid} = start_link(), Pid end,
     fun(Pid) -> gen_server:stop(Pid) end,
     fun(_Pid) ->
         fun() ->
             {ok, Created} = create((test_offer())#{pickup_by => <<"2020-01-01T10:00:00Z">>}),
             Id = maps:get(id, Created),
             {ok, [Expired]} = list(),
             {ok, Audit} = audit(Id),
             ?assertEqual(expired, maps:get(status, Expired)),
             ?assertEqual(expired, maps:get(action, lists:last(Audit)))
         end
     end}.
-endif.

transition(Id, State = #{offers := Offers, audit := Audit}, Fun) ->
    case maps:find(Id, Offers) of
        error -> {reply, {error, not_found}, State};
        {ok, Offer} ->
            case Fun(Offer) of
                {error, Why} -> {reply, {error, Why}, State};
                {ok, Updated} ->
                    Action = audit_action(maps:get(status, Offer), maps:get(status, Updated)),
                    Actor = actor_for(Updated),
                    Detail = audit_detail(Updated),
                    NewAudit = append_audit(Audit, Id, Action, Actor, Detail),
                    broadcast(#{type => offer_updated, offer => Updated}),
                    {reply, {ok, Updated}, State#{offers := Offers#{Id => Updated}, audit := NewAudit}}
            end
    end.

audit_action(_From, claimed) -> claimed;
audit_action(_From, collected) -> collected;
audit_action(_From, cancelled) -> cancelled;
audit_action(_From, exception) -> exception_reported;
audit_action(_From, resolved) -> exception_resolved;
audit_action(_From, To) -> To.

actor_for(Offer) ->
    case maps:get(status, Offer) of
        claimed -> maps:get(claimed_by, Offer, maps:get(recipient, Offer, <<"unknown">>));
        collected -> maps:get(confirmed_by, maps:get(handoff, Offer), <<"unknown">>);
        exception -> maps:get(actor, maps:get(exception, Offer), <<"unknown">>);
        resolved -> maps:get(actor, maps:get(resolution, Offer), <<"unknown">>);
        cancelled -> maps:get(cancelled_by, Offer, <<"unknown">>);
        _ -> <<"system">>
    end.

audit_detail(Offer) ->
    Status = maps:get(status, Offer),
    Base = #{status => Status},
    case Status of
        collected -> Base#{quantity => maps:get(collected_quantity, Offer),
                           handoff => maps:get(handoff, Offer)};
        exception -> Base#{exception => maps:get(exception, Offer)};
        resolved -> Base#{exception => maps:get(exception, Offer),
                          resolution => maps:get(resolution, Offer)};
        _ -> Base
    end.

append_audit(Audit, Id, Action, Actor, Details) ->
    Audit ++ [#{offer_id => Id, action => Action, actor => Actor,
                at => now_iso(), details => Details}].

expire_offers(State = #{offers := Offers, audit := Audit}) ->
    {NewOffers, NewAudit} = maps:fold(fun(Id, Offer, {Os, As}) ->
        case maps:get(status, Offer) =:= available andalso expired(Offer) of
            true ->
                Updated = Offer#{status => expired, expired_at => now_iso()},
                EventAudit = append_audit(As, Id, expired, <<"system">>, #{status => expired}),
                broadcast(#{type => offer_updated, offer => Updated}),
                {Os#{Id => Updated}, EventAudit};
            false -> {Os, As}
        end
    end, {Offers, Audit}, Offers),
    State#{offers := NewOffers, audit := NewAudit}.

nonempty(Value) when is_binary(Value) -> byte_size(string:trim(Value)) > 0;
nonempty(_) -> false.

broadcast(Event) -> lists:foreach(fun(Pid) -> Pid ! {offer_event, Event} end,
                                  pg:get_members(?GROUP)).

expired(Offer) ->
    case calendar:rfc3339_to_system_time(binary_to_list(maps:get(pickup_by, Offer)), [{unit, second}]) of
        Deadline -> Deadline =< erlang:system_time(second)
    end.

now_iso() -> list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second),
                                                            [{unit, second}, {offset, "Z"}])).
