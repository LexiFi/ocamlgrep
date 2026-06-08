(* This file is part of the ocamlgrep package
   See the attached LICENSE file.
   Copyright (C) 2000-2026 LexiFi

   Originally written by Nicolás Ojeda Bär (LexiFi);
   maintained by Martin Jambon (LexiFi). *)
(*
   Command-line interface and entry point for the standalone 'ocamlgrep'
   command. This is a thin wrapper around the [Ocamlgrep] library, mirroring
   the original ocamlgrep CLI so users can run it independently of the
   merlin server.
*)

open Printf

(* Configuration derived from command-line parsing and from environment
   variables *)
type conf = {
  query : string;
  scan_root : string;
  debug : bool;
  strict : bool;
  use_color : bool;
}

(* Colors are emitted unless the user opts out via the standard NO_COLOR env
   variable (https://no-color.org/). This keeps the snapshot tests readable
   without changing the default interactive behavior. *)
let use_color () =
  match Sys.getenv_opt "NO_COLOR" with
  | Some s when s <> "" -> false
  | _ -> true

let handle_event ~has_finding ~has_warning (conf : conf) (ev : Ocamlgrep.event)
    =
  match ev with
  | Scan_module module_ ->
      if conf.debug then eprintf "scan module %s\n%!" module_
  | Warning msg ->
      has_warning := true;
      Ocamlgrep.warn ~use_color:conf.use_color msg
  | Finding finding ->
      has_finding := true;
      printf "%s%!" (Ocamlgrep.show_finding ~use_color:conf.use_color finding)

let usage_msg =
  {|Usage: ocamlgrep <pattern> [scan_root]

Search a Dune project for OCaml code matching a structural pattern.
ocamlgrep walks the cmt files under _build/ and matches each typed
expression against <pattern>, which must be a valid OCaml expression.
The project's cmt files must be up to date: run `dune build @check`
first.

Pattern syntax
==============

  __                Matches any expression or record field. Often
                    called a "wildcard"; the same role as a
                    "metavariable" in coccinelle or semgrep.

  __1, __2, ...     Numbered metavariables. Match any expression and
                    require *equality* across all occurrences with
                    the same number. For example,
                      match __ with Some __1 -> Some __1 | _ -> None
                    only matches branches that return their input
                    unchanged.

  Foo, M.f          A value or constructor identifier matches as a
                    suffix of the fully qualified path of the typed
                    expression: `f` matches `Module.f`, `M.f` matches
                    `Outer.M.f`. This makes patterns robust to
                    `open`s in the matched code.

  foo a b           In a function application, you can omit any
                    argument of the actual call. The special forms
                    `foo ?arg:PRESENT` and `foo ?arg:MISSING` enforce
                    that an optional argument is supplied or omitted
                    at the call site.

  (e : t)           Type-constrained match. Matches any expression
                    that matches `e` and whose inferred type unifies
                    with `t`. The wildcard `__` is allowed in `t`.

  match e with ...  Clauses are matched as a set, in any order. A
                    single clause in the pattern may match multiple
                    clauses in the code. Same set semantics applies
                    to record expressions.

  e.lid             Matches both reads (`x.lid`) and writes
                    (`x.lid <- _`). The special form `__.id` also
                    matches record patterns `{...; P.id; ...}`, so
                    `__.foo` finds every read or write of field
                    `foo`, including in patterns.

Examples
========

  ocamlgrep 'List.filter'
  ocamlgrep '(__ (__ : floatarray) : float array)'
  ocamlgrep 'List.rev __ @ __'
  ocamlgrep 'match __ with None -> __ | Some __1 -> Some __1'
  ocamlgrep 'List.fold_left __ __ (List.map __ __)'
  ocamlgrep 'Stdlib.max (__ : float) __'

Output
======

Each finding is rendered as a header line giving the file and
location range, followed by the matched source lines with an
OCaml-compiler-style gutter:

  foo.ml:5:10-22:
  5 |   let x = List.length xs

  foo.ml:6:2-8:9:
  6 |   match x with
  7 |   | None -> None
  8 |   | Some y -> Some y

The matched range is highlighted in red unless the standard NO_COLOR
environment variable is set (https://no-color.org/).

Exit codes
==========

0: one or more matches were found
1: no matches were found
2: an error occurred, or a warning occurred in --strict mode

Options
=======|}

let parse_argv () =
  let anon_args = ref [] in
  let debug = ref false in
  let strict = ref false in
  let options =
    [
      ("--debug", Arg.Set debug, " print debugging information on stderr");
      ( "--strict",
        Arg.Set strict,
        " exit with a nonzero code if there's any warning (see \"exit codes\")"
      );
    ]
  in
  Arg.parse options (fun arg -> anon_args := arg :: !anon_args) usage_msg;
  let query, scan_root =
    match List.rev !anon_args with
    | [ query ] -> (query, ".")
    | [ query; scan_root ] -> (query, scan_root)
    | _ ->
        Arg.usage [] usage_msg;
        exit 1
  in
  {
    query;
    scan_root;
    debug = !debug;
    strict = !strict;
    use_color = use_color ();
  }

(* Exit codes as documented in --help *)
let exit_matched = 0
let exit_no_match = 1
let exit_error = 2

let main () =
  try
    let conf = parse_argv () in
    let has_finding = ref false in
    let has_warning = ref false in
    match
      Ocamlgrep.incremental_search ~debug:conf.debug ~scan_root:conf.scan_root
        (handle_event ~has_finding ~has_warning conf)
        conf.query
    with
    | Ok () ->
        if conf.strict && !has_warning then exit exit_error
        else if !has_finding then exit exit_matched
        else exit exit_no_match
    | Error msg -> failwith msg
  with
  | exn ->
      let msg =
        match exn with
        | Failure s
        | Sys_error s ->
            s
        | exn -> Printexc.to_string exn
      in
      Ocamlgrep.error ~use_color:(use_color ()) msg;
      exit exit_error

let () = main ()
