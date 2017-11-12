%%%-------------------------------------------------------------------
%%% File:      geas_doc.erl
%%% @author    Eric Pailleau <geas@crownedgrouse.com>
%%% @copyright 2015 crownedgrouse.com
%%% @doc
%%% Guess Erlang Applicaion Scattering
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

-export([generate/2, get_rel_list/0]).

% List of known releases
-define(REL_LIST, ["R15", "R15B", "R15B01", "R15B02", "R15B03", "R15B03-1",
                   "R16B", "R16B01", "R16B02", "R16B03", "R16B03-1",
                   "17.0", "17.1", "17.3", "17.4", "17.5",
		             "18.0", "18.1", "18.2", "18.3",
		             "19.0", "19.1", "19.2", "19.3",
                   "20.0", "20.1"]).

%% This module generate the geas_db.hrl
%% providing the min and max release of any Erlang/OTP function

%%-------------------------------------------------------------------------
%% @doc Generate target geas database from inventory root path
%% @end
%%-------------------------------------------------------------------------
-spec generate(list(), list()) -> ok.

generate(Dir, Target) -> generate(filename:join([Dir, "relinfos", "term"]),
                                  filename:join([Dir, "reldiffs", "term"]),
                                  Target).

%%-------------------------------------------------------------------------
%% @doc Generate target geas database from info and diff directories
%% @end
%%-------------------------------------------------------------------------
-spec generate(list(), list(), list()) -> ok | {'error',atom()}.

generate(IDir, DDir, Target) -> {ok, TargetIo} = file:open(Target, [write]),
                                do_header(TargetIo),
                                do_defines(TargetIo),
                                % List all functions removed in what release [{module, release}, ...]
                                Data11 = lists:flatten(get_removed_functions(DDir)),
                                do_max_functions(TargetIo, Data11),
                                % list of modules removed in what release [{module, release}, ...]
                                Data12 = lists:flatten(get_removed_modules(DDir)),
                                do_max_modules(TargetIo, Data12),
                                io:nl(TargetIo),
                                % List all functions added in what release [{module, release}, ...]
                                Data21 = lists:flatten(get_added_functions(DDir)),
                                do_min_functions(TargetIo, Data21),
                                % List the whole modules of oldest known release
                                {ok, [R1]} = file:consult(filename:join(IDir, hd(?REL_LIST))),
                                {mfa, Data22} = lists:keyfind(mfa, 1, R1),
                                do_min_modules(TargetIo, Data22),
                                % Close file
                                file:close(TargetIo).

%%-------------------------------------------------------------------------
%% @doc Get all removed functions from diff directory
%% @end
%%-------------------------------------------------------------------------
-spec get_removed_functions(list()) -> list().

get_removed_functions(DDir) ->
       % List all reldiffs files
       {ok, Reldiffs} = file:list_dir(DDir),
       % Loop over list and pick up all removed functions, linked to 'From'
       _RMF = lists:map(fun(F) -> % Load file
                              {ok, [R]} = file:consult(filename:join(DDir, F)),
                              % Pick 'From' where last presence of function is
                              {from, From} = lists:keyfind(from, 1, R),
                              From_s =  atom_to_list(From),
                              % Pick 'functions' entry
                              {functions, Fs} = lists:keyfind(functions, 1, R),
                              % Pick 'removed' entry
                              {removed, RF} = lists:keyfind(removed, 1, Fs),

                              % Compose [{module, function, arity, release}, ...]
                              lists:map(fun({Mm, FL}) ->
                                            lists:map(fun(Fa) ->
                                                          Fa_s = atom_to_list(Fa),
                                                          % Extract function and arity
                                                          [Ff, Aa] = string:tokens(Fa_s, "/"),
                                                          {Int, _} = string:to_integer(Aa),
                                                          [{Mm, list_to_atom(Ff), Int, From_s}]
                                                       end, FL)
                                        end, RF)
                    end, Reldiffs).

%%-------------------------------------------------------------------------
%% @doc Get all added functions from diff directory
%% @end
%%-------------------------------------------------------------------------
-spec get_added_functions(list()) -> list().

get_added_functions(DDir) ->
       % List all reldiffs files
       {ok, Reldiffs} = file:list_dir(DDir),
       % Loop over list and pick up all removed functions, linked to 'From'
       _AMF = lists:map(fun(F) -> % Load file
                              {ok, [R]} = file:consult(filename:join(DDir, F)),
                              % Pick 'To' where new presence of function is
                              {to, To} = lists:keyfind(to, 1, R),
                              To_s =  atom_to_list(To),
                              % Pick 'functions' entry
                              {functions, Fs} = lists:keyfind(functions, 1, R),
                              % Pick 'added' entry
                              {new, NF} = lists:keyfind(new, 1, Fs),

                              % Compose [{module, function, arity, release}, ...]
                              lists:map(fun({Mm, FL}) ->
                                            lists:map(fun(Fa) ->
                                                          Fa_s = atom_to_list(Fa),
                                                          % Extract function and arity
                                                          [Ff, Aa] = string:tokens(Fa_s, "/"),
                                                          {Int, _} = string:to_integer(Aa),
                                                          [{Mm, list_to_atom(Ff), Int, To_s}]
                                                       end, FL)
                                        end, NF)
                    end, Reldiffs).

%%-------------------------------------------------------------------------
%% @doc Get all removed modules from diff directory
%% @end
%%-------------------------------------------------------------------------
-spec get_removed_modules(list()) -> list().

get_removed_modules(DDir) ->
         % List all reldiffs files
         {ok, Reldiffs} = file:list_dir(DDir),
         % Loop over list and pick up all removed modules, linked to 'To'
         _RMS = lists:map(fun(F) -> % Load file
                                  {ok, [R]} = file:consult(filename:join(DDir, F)),
                                  % Pick 'From'
                              	  {from, From} = lists:keyfind(from, 1, R),
                                  % Pick 'modules' entry
                                  {modules, M} = lists:keyfind(modules, 1, R),
                                  % Pick 'removed' entry
                                  {removed, RM} = lists:keyfind(removed, 1, M),
                                  % Compose [{module, release}, ...]
                                  lists:map(fun(X) -> [{X, atom_to_list(From)}] end, RM)
                        end, Reldiffs) .

%%-------------------------------------------------------------------------
%% @doc Geas database header
%% @end
%%-------------------------------------------------------------------------
do_header(Io) ->  Header = ["%% File: geas_db.hrl"
                               ,"%% @author    Generated by geas_db module "
                               ,"%% @warning   DO NOT EDIT BY HAND OR YOUR CHANGE WILL BE LOST"
                               ,"%% @copyright Eric Pailleau <geas@crownedgrouse.com>"
                               ,"%% @licence   https://github.com/crownedgrouse/geas/blob/master/LICENCE"
                               ,"%% @doc "
                               ,"%% Geas database "
                               ,"%% @end "
                               ],
                  io:put_chars(Io, erl_prettypr:format(erl_syntax:comment(Header))).
%%-------------------------------------------------------------------------
%% @doc defines in top of Geas database
%% @end
%%-------------------------------------------------------------------------
do_defines(Io) ->  DefMin = erl_syntax:attribute(
                                    erl_syntax:atom('define'),
                                    [erl_syntax:atom('GEAS_MIN_REL'),
                                     erl_syntax:string(hd(?REL_LIST))]),
                   DefMax = erl_syntax:attribute(
                                    erl_syntax:atom('define'),
                                    [erl_syntax:atom('GEAS_MAX_REL'),
                                     erl_syntax:string(hd(lists:reverse(?REL_LIST)))]),
                   io:put_chars(Io, erl_prettypr:format(DefMin)),
                   io:nl(Io),
                   io:put_chars(Io, erl_prettypr:format(DefMax)),
                   io:nl(Io),
                   io:nl(Io).

%%-------------------------------------------------------------------------
%% @doc Oldest modules in min release
%% @end
%%-------------------------------------------------------------------------
do_min_modules(Io, Data) -> lists:foreach(fun({M, _}) -> io:format(Io,"rel_min({~p, _, _}) -> ?GEAS_MIN_REL ;~n", [M]) end, Data),
                            % If no match, MFA is probably from a non core Erlang (i.e. private) module
                            io:format(Io,"rel_min({_, _, _}) -> ~p .~n", [undefined]) .

%%-------------------------------------------------------------------------
%% @doc Add all removed modules in reldiffs
%% @end
%%-------------------------------------------------------------------------
do_max_modules(Io, Data) -> lists:foreach(fun({M, R}) -> io:format(Io,"rel_max({~p, _, _}) -> ~p ;~n", [M, R]) end, Data),
                            % If no match, MFA is still available in max release
                            io:format(Io,"rel_max({_, _, _}) -> ?GEAS_MAX_REL.~n", []) .

%%-------------------------------------------------------------------------
%% @doc Oldest modules in min release
%% @end
%%-------------------------------------------------------------------------
do_min_functions(Io, Data) -> lists:foreach(fun({M, F, A, R}) -> io:format(Io,"rel_min({~p, ~p, ~p}) -> ~p ;~n", [M, F, A, R]) end, Data).

%%-------------------------------------------------------------------------
%% @doc Add all removed modules in reldiffs
%% @end
%%-------------------------------------------------------------------------
do_max_functions(Io, Data) -> lists:foreach(fun({M, F, A, R}) -> io:format(Io,"rel_max({~p, ~p, ~p}) -> ~p ;~n", [M, F, A, R]) end, Data).

%%-------------------------------------------------------------------------
%% @doc Give release list
%% @end
%%-------------------------------------------------------------------------
get_rel_list() -> ?REL_LIST.
