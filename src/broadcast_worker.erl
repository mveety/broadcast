-module(broadcast_worker).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3,
         start_link/2, terminate/2]).

sendmsgs(_, [], _) ->
    ok;
sendmsgs(Parent, [Pid|T], Msg) ->
    case is_process_alive(Pid) of
        true ->
            Pid ! Msg;
        false ->
            gen_server:cast(Parent, {defunct_pid, Pid}),
            gen_server:cast(self(), {remove_pid, Pid})
    end,
    sendmsgs(Parent, T, Msg).

start_link(Name, Parent) ->
    gen_server:start_link(?MODULE, [Name, Parent], []).

init([Name, Parent]) ->
    State = #{name => Name,
              parent => Parent,
              pids => []},
    ok = gen_server:cast(Parent, {register_worker, Name, self()}),
    {ok, State}.

handle_call({update_pids, Pids}, _From, State0) ->
    State = State0#{pids => Pids},
    {reply, ok, State};
handle_call({sendmsg, Msg}, _From, State = #{parent := Parent, pids := Pids}) ->
    sendmsgs(Parent, Pids, Msg),
    {reply, ok, State};
handle_call(endpoints, _From, State = #{pids := Pids}) ->
    {reply, {ok, Pids}, State};
handle_call(stats, _From, State = #{name := Name, pids := Pids}) ->
    Stats = {Name, {num, length(Pids)}, {pids, Pids}},
    {reply, Stats, State};
handle_call(_, _, State) ->
    {noreply, State}.

handle_cast({add_pid, Pid}, State0 = #{pids := Pids0}) ->
    case lists:member(Pid, Pids0) of
        true ->
            {noreply, State0};
        false ->
            Pids = [Pid|Pids0],
            State = State0#{pids => Pids},
            {noreply, State}
    end;
handle_cast({remove_pid, Pid}, State0 = #{pids := Pids0}) ->
    Pids = lists:delete(Pid, Pids0),
    State = State0#{pids => Pids},
    {noreply, State};
handle_cast({sendmsg, Msg}, State = #{parent := Parent, pids := Pids}) ->
    sendmsgs(Parent, Pids, Msg),
    {noreply, State};
handle_cast(_, State) ->
    {noreply, State}.

handle_info(_, State) ->
    {noreply, State}.

code_change(_, State, _) ->
    {ok, State}.

terminate(_, _) ->
    ok.
