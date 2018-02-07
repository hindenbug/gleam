-module(gleam_codegen).
-include("gleam_records.hrl").
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([module/1]).

module(#gleam_ast_module{name = Name, functions = Funs, exports = Exports}) ->
  PrefixedName = prefix_module(Name),
  C_name = cerl:c_atom(PrefixedName),
  C_exports =
    [ cerl:c_fname(module_info, 0)
    , cerl:c_fname(module_info, 1)
    | lists:map(fun export/1, Exports)
    ],
  C_definitions =
    [ module_info(PrefixedName, [])
    , module_info(PrefixedName, [cerl:c_var(item)])
    | lists:map(fun function/1, Funs)
    ],
  Attributes = [],
  Core = cerl:c_module(C_name, C_exports, Attributes, C_definitions),
  {ok, Core}.

export({Name, Arity}) when is_atom(Name), is_integer(Arity) ->
  cerl:c_fname(Name, Arity).

module_info(ModuleName, Params) when is_atom(ModuleName) ->
  Body = cerl:c_call(cerl:c_atom(erlang),
                     cerl:c_atom(get_module_info),
                     [cerl:c_atom(ModuleName) | Params]),
  C_fun = cerl:c_fun(Params, Body),
  C_fname = cerl:c_fname(module_info, length(Params)),
  {C_fname, C_fun}.

function(#gleam_ast_function{name = Name, args = Args, body = Body}) ->
  Arity = length(Args),
  C_fname = cerl:c_fname(Name, Arity),
  C_args = lists:map(fun var/1, Args),
  C_body = body(Body),
  {C_fname, cerl:c_fun(C_args, C_body)}.

body(Expressions) ->
  % TODO: Support multiple expressions
  [Expression] = Expressions,
  expression(Expression).

var(Atom) when is_atom(Atom) ->
  cerl:c_var(Atom).

expression(#gleam_ast_var{name = Name}) when is_atom(Name) ->
  cerl:c_var(Name);
expression(#gleam_ast_call{module = Mod, name = Name, args = Args}) when is_atom(Name) ->
  C_module = cerl:c_atom(prefix_module(Mod)),
  C_fname = call_fname(Name),
  C_args = lists:map(fun expression/1, Args),
  cerl:c_call(C_module, C_fname, C_args).

call_fname('/') -> cerl:c_atom('div');
call_fname('+.') -> cerl:c_atom('+');
call_fname('-.') -> cerl:c_atom('-');
call_fname('*.') -> cerl:c_atom('*');
call_fname('/.') -> cerl:c_atom('/');
call_fname('<=') -> cerl:c_atom('=<');
call_fname(Name) -> cerl:c_atom(Name).

prefix_module(erlang) -> erlang;
prefix_module(Name) when is_atom(Name) -> list_to_atom("Gleam." ++ atom_to_list(Name)).