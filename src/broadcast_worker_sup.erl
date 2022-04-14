-module(broadcast_worker_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link(broadcast_worker_sup, []).

init(_Args) ->
    SupFlags = #{strategy => simple_one_for_one,
                 intensity => 0,
                 period => 1},
    ChildSpecs =[#{id => broadcast_worker,
                   start => {broadcast_worker, start_link, []},
                   restart => permanent,
                   shutdown => brutal_kill}],
    {ok, {SupFlags, ChildSpecs}}.
