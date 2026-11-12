-module(nourish_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/", nourish_page, ["index.html"]},
            {"/api/events", nourish_events, []},
            {"/api/impact", nourish_http, [impact]},
            {"/api/offers", nourish_http, [offers]},
            {"/api/offers/:id/:action", nourish_http, [offer_action]},
            {"/assets/app.js", nourish_page, ["app.js"]},
            {"/assets/app.css", nourish_page, ["app.css"]}
        ]}
    ]),
    Port = application:get_env(nourish, port, 8080),
    Children = [
        #{id => nourish_offers, start => {nourish_offers, start_link, []},
          restart => permanent, shutdown => 5000, type => worker, modules => [nourish_offers]},
        #{id => nourish_http_listener,
          start => {cowboy, start_clear, [nourish_http_listener, [{port, Port}],
                                           #{env => #{dispatch => Dispatch}}]},
          restart => permanent, shutdown => 5000, type => worker, modules => [cowboy_listener]}
    ],
    {ok, {{one_for_one, 5, 10}, Children}}.
