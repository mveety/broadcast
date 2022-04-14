-module(broadcast_util).
-export([split_list/2, part_list/2, pad_list/3]).

split_list(List, Max) ->
    element(1, lists:foldl(fun (E, {[Buff|Acc], C}) when C < Max ->
                                   {[[E|Buff]|Acc], C+1};
                               (E, {[Buff|Acc], _}) ->
                                   {[[E],Buff|Acc], 1};
                               (E, {[], _}) ->
                                   {[[E]], 1}
                           end, {[], 0}, List)).

part_list(List, Parts) ->
    Len0 = length(List),
    Len = case Len0 rem Parts of
              0 -> Len0;
              X -> Len0 + (Parts - X)
          end,
    Max = Len div Parts,
    split_list(List, Max).

pad_list(List, Len, Elem) when length(List) < Len ->
    pad_list(List ++ [Elem], Len, Elem);
pad_list(List, _, _) ->
    List.
