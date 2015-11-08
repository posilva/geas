%%%-------------------------------------------------------------------
%%% File:      geas_doc.erl
%%% @author    Eric Pailleau <geas@crownedgrouse.com>
%%% @copyright 2015 crownedgrouse.com
%%% @doc  
%%% Guess Erlang Application Scattering
%%% Database generation module
%%% @end  
%%%
%%% Permission to use, copy, modify, and/or distribute this software
%%% for any purpose with or without fee is hereby granted, provided
%%% that the above copyright notice and this permission notice appear
%%% in all copies.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
%%% WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
%%% WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
%%% AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
%%% CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
%%% LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
%%% NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
%%% CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%%%
%%% Created : 2015-11-05
%%%-------------------------------------------------------------------
-module(geas_db).
-author("Eric Pailleau <geas@crownedgrouse.com>").

-export([generate/2]).

%% This module generate the geas_db.hrl
%% providing the min and max release of any Erlang/OTP function

generate(Dir, Target) -> generate(filename:join([Dir, "relinfos", "term"]), 
                                  filename:join([Dir, "reldiffs", "term"]), 
                                  Target).

generate(IDir, DDir, Target) -> {ok, TargetIo} = file:open(Target, [write]),
                                do_header(TargetIo),
                                do_defines(TargetIo),
                                % list of modules removed in what release [{module, release}, ...]
                                Data1 = lists:flatten(get_removed_modules(DDir)),
                                do_max(TargetIo, Data1),
                                io:nl(TargetIo),
                                % List the whole modules of oldest known release
                                {ok, [R1]} = file:consult(filename:join(IDir, "R15")),
                                {mfa, Data2} = lists:keyfind(mfa, 1, R1),
                                do_min(TargetIo, Data2).

get_removed_modules(DDir) -> % List all reldiffs files
                             {ok, Reldiffs} = file:list_dir(DDir),
                             % Loop over list and pick up all removed modules, linked to 'To' 
                             RMS = lists:map(fun(F) -> % Load file
                                                      {ok, [R]} = file:consult(filename:join(DDir, F)),
                                                      % Pick 'To'
                                                      {to, To} = lists:keyfind(to, 1, R),                                                        
                                                      % Pick 'modules' entry
                                                      {modules, M} = lists:keyfind(modules, 1, R),
                                                      % Pick 'removed' entry
                                                      {removed, RM} = lists:keyfind(removed, 1, M),
                                                      % Compose [{module, release}, ...]
                                                      lists:map(fun(X) -> [{X, atom_to_list(To)}] end, RM)
                                            end, Reldiffs) .


do_header(Io) ->  Header = ["%% File: geas_db.hrl"
                               ,"%% @author    Generated by geas_db module "
                               ,"%% @copyright "
                               ,"%% @warning   DO NOT EDIT BY HAND OR YOUR CHANGE WILL BE LOST"
                               ,"%% @doc "
                               ,"%% Geas database "
                               ,"%% @end "
                               ],
                  io:put_chars(Io, erl_prettypr:format(erl_syntax:comment(Header))).

do_defines(Io) ->  DefMin = erl_syntax:attribute(
                                    erl_syntax:atom('define'), 
                                    [erl_syntax:atom('GEAS_MIN_REL'),
                                     erl_syntax:string("R15")]),
                   DefMax = erl_syntax:attribute(
                                    erl_syntax:atom('define'), 
                                    [erl_syntax:atom('GEAS_MAX_REL'),
                                     erl_syntax:string("18.1")]),
                   io:put_chars(Io, erl_prettypr:format(DefMin)),
                   io:nl(Io),
                   io:put_chars(Io, erl_prettypr:format(DefMax)),
                   io:nl(Io).


do_max(Io, Data) -> %do_max_functions(Data),
                    do_max_modules(Io, Data).

do_min(Io, Data) -> %do_min_functions(Data),
                    do_min_modules(Io, Data).

%%-------------------------------------------------------------------------
%% @doc Oldest modules in min release
%%-------------------------------------------------------------------------
do_min_modules(Io, Data) -> lists:foreach(fun({M, _}) -> io:format(Io,"min({~p, _, _}) -> ?GEAS_MIN_REL ;~n", [M]) end, Data),
                            % If no match, MFA is probably from a non core Erlang (i.e. private) module
                            io:format(Io,"min({_, _, _}) -> ~p .~n", [undefined]) .

%%-------------------------------------------------------------------------
%% @doc Add all removed modules in reldiffs
%%-------------------------------------------------------------------------
do_max_modules(Io, Data) -> lists:foreach(fun({M, R}) -> io:format(Io,"max({~p, _, _}) -> ~p ;~n", [M, R]) end, Data),
                            % If no match, MFA is still available in max release
                            io:format(Io,"max({_, _, _}) -> ?GEAS_MAX_REL.~n", []) . 
                      


