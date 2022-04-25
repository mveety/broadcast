-module(broadcast).
-export([get_server/1, add_endpoint/3, remove_endpoint/2, stats/1, send/2,
         send_nowait/2, start_link/0, start_link/1, start_link/2, endpoints/1]).

get_server(SupPid) ->
    Siblings = supervisor:which_children(SupPid),
    {_, Pid, _, _} = lists:keyfind(broadcast_server, 1, Siblings),
    Pid.

add_endpoint(SupPid, Name, Pid) ->
    Server = get_server(SupPid),
    gen_server:call(Server, {add_endpoint, Name, Pid}).

remove_endpoint(SupPid, Name) ->
    Server = get_server(SupPid),
    gen_server:call(Server, {remove_endpoint, Name}).

stats(SupPid) ->
    Server = get_server(SupPid),
    gen_server:call(Server, stats).

send(SupPid, Message) ->
    Server = get_server(SupPid),
    gen_server:call(Server, {sendmsg, Message}).

send_nowait(SupPid, Message) ->
    Server = get_server(SupPid),
    gen_server:cast(Server, {sendmsg, Message}).

endpoints(SupPid) ->
    Server = get_server(SupPid),
    gen_server:call(Server, endpoints).

start_link() ->
    broadcast_sup:start_link(none, 4).

start_link(Workers) ->
    broadcast_sup:start_link(none, Workers).

start_link(Name, Workers) ->
    broadcast_sup:start_link(Name, Workers).
