-module(broadcast_server).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3,
         terminate/2, start_link/2]).
-include_lib("stdlib/include/ms_transform.hrl").
-record(endpoint, {name, pid, aux}).


start_worker(Workersup, Name) ->
    {ok, Pid} = supervisor:start_child(Workersup, [Name, self()]),
    {Name, Pid}.

start_workers(_, 0, Acc) ->
    Acc;
start_workers(Workersup, N, Acc) ->
    Name0 = "worker" ++ integer_to_list(N),
    Name = list_to_atom(Name0),
    Worker = start_worker(Workersup, Name),
    start_workers(Workersup, N-1, [Worker|Acc]).
start_workers(Workersup, N) ->
    start_workers(Workersup, N, []).

%% remove_worker(Workers, Pid) ->
%%     Deselect = fun({_, P}, P) -> [];
%%                   (W, _) -> W
%%                end,
%%     lists:flatten([Deselect(X, Pid) || X <- Workers]).

select_random_worker(Workers) ->
    lists:nth(rand:uniform(length(Workers)), Workers).

call_all_workers(Workers, Request) ->
    Fun = fun ({_, Pid}, Req) -> gen_server:call(Pid, Req) end,
    [Fun(X, Request) || X <- Workers].

cast_all_workers(Workers, Request) ->
    Fun = fun({_, Pid}, Req) -> gen_server:cast(Pid, Req) end,
    [Fun(X, Request) || X <- Workers].

divide_work(Workers, List) ->
    WorkersLen = length(Workers),
    Work0 = broadcast_util:part_list(List, WorkersLen),
    Work = broadcast_util:pad_list(Work0, WorkersLen, []),
    SendAll = fun SendAll([], []) ->
                      ok;
                  SendAll([], _) ->
                      error(work_not_split); % maybe this should error
                  SendAll(_, []) ->
                      ok; % if endpoints isn't divisible by workers
                  SendAll([WH|WT], [EH|ET]) ->
                      {_, WP} = WH,
                      gen_server:call(WP, {update_pids, EH}),
                      SendAll(WT, ET)
              end,    
    SendAll(Workers, Work).

start_link(SupPid, Workers) ->
    gen_server:start_link(?MODULE, [SupPid, Workers], []).

init([SupPid, NWorkers]) ->
    BaseState = #{sup => SupPid, state => init},
    gen_server:cast(self(), {initialize, NWorkers}),
    {ok, BaseState}.

handle_cast({initialize, NWorkers}, State0 = #{sup := SupPid, state := init}) ->
    Siblings = supervisor:which_children(SupPid),
    {_, Workersup, _, _} = lists:keyfind(workersup, 1, Siblings),
    Workers = start_workers(Workersup, NWorkers),
    Endpoints = ets:new(bcast_proc_table, [set, public, {keypos, #endpoint.name},
                                           {read_concurrency, true}]),
    State = State0#{sup => SupPid,
                    state => run,
                    workersup => Workersup,
                    endpoints => Endpoints,
                    workers => Workers,
                    ops => 0},
    {noreply, State};

handle_cast({defunct_pid, Pid}, State0 = #{endpoints := Endpoints, ops := Ops}) ->
    MS = ets:fun2ms(fun(#endpoint{pid = P}) when P == Pid -> true end),
    ets:select_delete(Endpoints, MS),
    State = State0#{ops => Ops + 1},
    {noreply, State};

handle_cast({register_worker, Name, Pid},
            State0 = #{endpoints := Endpoints, workers := Workers0, ops := Ops}) ->
    Workers1 = proplists:to_map(Workers0),
    Workers2 = Workers1#{Name => Pid},
    Workers = proplists:from_map(Workers2),
    State = State0#{workers => Workers, ops => Ops},
    MS = ets:fun2ms(fun(#endpoint{pid = P}) -> P end),
    Pids = ets:select(Endpoints, MS),
    divide_work(Workers, Pids),    
    {noreply, State};

handle_cast({sendmsg, Msg}, State = #{workers := Workers}) ->
    cast_all_workers(Workers, {sendmsg, Msg}),
    {noreply, State};

handle_cast(_, State) ->
    {noreply, State}.

handle_call({add_endpoint, Name, Pid}, _From,
            State0 = #{endpoints := Endpoints, workers := Workers, ops := Ops0}) ->
    Endpoint = #endpoint{name = Name,
                         pid = Pid,
                         aux = none},
    true = ets:insert(Endpoints, Endpoint),
    Worker = select_random_worker(Workers),
    Ops = Ops0 + 1,
    case Ops > length(Workers) of
        true ->
            MS = ets:fun2ms(fun(#endpoint{pid = P}) -> P end),
            Pids = ets:select(Endpoints, MS),
            divide_work(Workers, Pids),
            State = State0#{ops => 0};
        false ->
            {_, WorkPid} = Worker,
            gen_server:cast(WorkPid, {add_pid, Pid}),
            State = State0#{ops => Ops}
    end,
    {reply, ok, State};

handle_call({remove_endpoint, Name}, _From,
            State0 = #{endpoints := Endpoints, workers := Workers, ops := Ops}) ->
    case ets:lookup(Endpoints, Name) of
        [] ->
            {reply, not_found, State0};
        [Endpoint] ->
            #endpoint{pid = Pid} = Endpoint,
            ets:delete(Endpoints, Name),
            cast_all_workers(Workers, {remove_pid, Pid}),
            State = State0#{ops => Ops + 1},
            {reply, ok, State}
    end;

handle_call(stats, _From, State = #{endpoints := Endpoints, workers := Workers}) ->
    WorkerStats = call_all_workers(Workers, stats),
    MS = ets:fun2ms(fun(X) -> X end),
    EPlist = ets:select(Endpoints, MS),
    Reply = [{endpoints, length(EPlist)}, {workers, WorkerStats}],
    {reply, Reply, State};

handle_call({sendmsg, Msg}, _From, State = #{workers := Workers}) ->
    S = call_all_workers(Workers, {sendmsg, Msg}),
    {reply, S, State};

handle_call(_, _From, State) ->
    {noreply, State}.

handle_info(_, State) ->
    {noreply, State}.

code_change(_, State, _) ->
    {ok, State}.

terminate(_, _) ->
    ok.
