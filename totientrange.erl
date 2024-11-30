-module(totientrange).
-export([hcf/2,
         relprime/2,
         sumTotient/3,
        eularWorker/0,
        euler/1,
        start_workers/1,
        assign_work/4,
        collect_results/3,
        workerName/1,
        workerChaos/2,
        supervisor/2
        ]).


workerName(N) ->
  list_to_atom( "worker" ++ integer_to_list(N)).


workerChaos(NVictims, NWorkers) ->
  lists:map(
    fun( _ ) ->
      timer:sleep(500), %% Sleep for .5s
      %% Choose a random victim
      WorkerNum = rand:uniform(NWorkers),
      io:format("workerChaos killing ~p~n", [workerName(WorkerNum)]),

      WorkerPid = whereis(workerName(WorkerNum)),
      if
      WorkerPid == undefined ->
        io:format("workerChaos already dead: ~p~n", [workerName(WorkerNum)]);
      true -> %% Kill Kill Kill
        exit(whereis(workerName(WorkerNum)),chaos)
      end
    end,
  lists:seq( 1, NVictims ) ).




hcf(X,0) -> X;
hcf(X,Y) -> hcf(Y,X rem Y).

relprime(X,Y) -> hcf(X,Y) == 1.

euler(N) ->
    RelprimeN = fun(Y) -> relprime(N,Y) end,
    length(lists:filter(RelprimeN, (lists:seq(1,N)))).


eularWorker() ->
  receive
    {work, CollectorID, WorkList} ->
      CollectorID ! {done, self(), lists:sum(lists:map(fun euler/1, WorkList))}
  end.



%% Take completion timestamp, and print elapsed time
printElapsed(S,US) ->
    {_, S2, US2} = os:timestamp(),
    %% Adjust Seconds if completion Microsecs > start Microsecs
    if
        US2-US < 0 ->
            S3 = S2-1,
            US3 = US2+1000000;
        true ->
            S3 = S2,
            US3 = US2
    end,
    io:format("Time taken in Secs, MicroSecs ~p ~p~n",[S3-S,US3-US]).



start_workers(0) -> [];
start_workers(Workers) ->
    [spawn_link(totientrange, eularWorker, []) | start_workers(Workers - 1)].


supervisor([], _) -> stop;
supervisor(Workers, Collector) ->
  process_flag(trap_exit, true),
  io:format("Supervising ~p workers ~n", [length(Workers)]),
  receive
    {'EXIT', ProcessName, normal} ->
      % Process is finished we can remove it from the list.
      supervisor(lists:delete(ProcessName, Workers), Collector);
    {'EXIT', ProcessName, _} ->
      % We register under the same name, so do not need to update the list.
      register(ProcessName, spawn_link(totientrange, eularWorker, [])),
      supervisor(Workers, Collector);
    finished ->
      io:format("Supervision complete~n")
  end.
  



assign_work([], _, _, _) -> ok;
assign_work(Work, [Worker], CollectorID, _) ->
  Worker ! {work, CollectorID, Work};

assign_work(Work, [Worker | Workers], CollectorID, Chunk ) ->
  {AsgWork, RemWork} = lists:split(Chunk, Work),

  Worker ! {work, CollectorID, AsgWork},
  assign_work(RemWork, Workers, CollectorID, Chunk).


collect_results(MasterId, [], FinalResult) ->
  MasterId ! {done, FinalResult};
collect_results(MasterId, [Worker | Workers], FinalResult) ->
  receive
    {done, Worker, Result} ->
      collect_results(MasterId, Workers, FinalResult + Result)
  end.


%%sumTotient lower upper = sum (map euler [lower, lower+1 .. upper])
sumTotient(Lower, Upper, MaxWorkers) ->
    {_, S, US} = os:timestamp(),
    

    Workers = start_workers(MaxWorkers),
    io:format("Workers ~p~n", [Workers]),
    Collector = spawn(totientrange, collect_results, [self(), Workers, 0]),

    Work = lists:seq(Lower, Upper),

    Chunk = length(Work) div length(Workers),

    assign_work(Work, Workers, Collector, Chunk),

    supervisor(Workers, Collector),

    receive
      {done, Res} ->
        io:format("Sum of totients: ~p~n", [Res]),
        printElapsed(S,US)
    end.

    