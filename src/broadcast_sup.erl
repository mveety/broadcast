-module(broadcast_sup).
-export([start_link/2, init/1]).

start_link(none, Workers) ->
    supervisor:start_link(broadcast_sup, [Workers]);
start_link(Name, Workers) ->
    supervisor:start_link(Name, broadcast_sup, [Workers]).

init([Workers]) ->
    Self = self(),
    SupFlags = #{strategy => one_for_all,
                 auto_shutdown => any_significant,
                 intensity => 10,
                 period => 5},
    ChildSpecs = [
                  #{id => workersup,
                    start => {broadcast_worker_sup, start_link, []},
                    restart => temporary,
                    significant => true,
                    type => supervisor},
                  #{id => broadcast_server,
                    start => {broadcast_server, start_link, [Self, Workers]},
                    restart => temporary,
                    type => worker,
                    significant => true,
                    shutdown => brutal_kill}
                 ],
    {ok, {SupFlags, ChildSpecs}}.
