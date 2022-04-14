-module(broadcast_sup).
-export([start_link/2, init/1]).

start_link(none, Workers) ->
    supervisor:start_link(broadcast_sup, [Workers]);
start_link(Name, Workers) ->
    supervisor:start_link(Name, broadcast_sup, [Workers]).

init([Workers]) ->
    Self = self(),
    SupFlags = #{strategy => one_for_all,
                 intensity => 10,
                 period => 5},
    ChildSpecs = [
                  #{id => workersup,
                    start => {broadcast_worker_sup, start_link, []},
                    restart => permanent,
                    type => supervisor},
                  #{id => broadcast_server,
                    start => {broadcast_server, start_link, [Self, Workers]},
                    restart => permanent,
                    type => worker,
                    shutdown => brutal_kill}
                 ],
    {ok, {SupFlags, ChildSpecs}}.
