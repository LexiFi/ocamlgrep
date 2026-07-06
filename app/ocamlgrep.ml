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
open Cmdliner

type output_format = Text | JSON

type conf = {
  query : string;
  scan_root : string option;
  chdir : string option;
  debug : bool;
  dune_root : string option;
  output_format : output_format;
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

(* Exit codes as documented in the man page *)
let exit_matched = 0
let exit_no_match = 1
let exit_error = 2

let run (conf : conf) =
  (match conf.chdir with
  | None -> ()
  | Some dir -> Sys.chdir dir);
  match conf.output_format with
  | Text ->
      let has_finding = ref false in
      let has_warning = ref false in
      (match
         Ocamlgrep.incremental_search
           ~debug:conf.debug
           ?dune_root:conf.dune_root
           ?scan_root:conf.scan_root
           (handle_event ~has_finding ~has_warning conf)
           conf.query
       with
      | Ok () ->
          if conf.strict && !has_warning then exit exit_error
          else if !has_finding then exit exit_matched
          else exit exit_no_match
      | Error msg -> failwith msg)
  | JSON ->
      let res =
        Ocamlgrep.search ~debug:conf.debug ?scan_root:conf.scan_root conf.query
      in
      print_string (Ocamlgrep.to_json res);
      flush stdout;
      if conf.strict && res.warnings <> [] then exit exit_error
      else if res.findings <> [] then exit exit_matched
      else exit exit_no_match

(****************************************************************************)
(* Command-line terms *)
(****************************************************************************)

let format_conv =
  let parse = function
    | "text" -> Ok Text
    | "json" -> Ok JSON
    | str ->
        Error (`Msg (sprintf "invalid format %S, expected 'text' or 'json'" str))
  in
  let print ppf = function
    | Text -> Format.pp_print_string ppf "text"
    | JSON -> Format.pp_print_string ppf "json"
  in
  Arg.conv ~docv:"FORMAT" (parse, print)

let query_term : string Term.t =
  let info =
    Arg.info [] ~docv:"PATTERN"
      ~doc:"OCaml expression used as a search pattern (see $(b,PATTERN SYNTAX))."
  in
  Arg.required (Arg.pos 0 (Arg.some Arg.string) None info)

let scan_root_term : string option Term.t =
  let info =
    Arg.info [] ~docv:"SCAN_ROOT"
      ~doc:
        "Directory or file to scan. Defaults to the whole Dune project rooted \
         at the current directory. Must be a relative path."
  in
  Arg.value (Arg.pos 1 (Arg.some Arg.string) None info)

let chdir_term : string option Term.t =
  let info =
    Arg.info [ "chdir" ] ~docv:"DIR"
      ~doc:"Change the current directory to $(docv) before doing any work."
  in
  Arg.value (Arg.opt (Arg.some Arg.string) None info)

let debug_term : bool Term.t =
  let info =
    Arg.info [ "debug" ] ~doc:"Print debugging information on stderr."
  in
  Arg.value (Arg.flag info)

let dune_root_term : string option Term.t =
  let info =
    Arg.info ["dune-root"] ~docv:"DUNE_ROOT"
      ~doc:
        "Force the Dune root folder to $(docv) instead of letting Dune \
         detect it. Use this if the target project was built with \
         'dune --root $(docv)'."
  in
  Arg.value (Arg.opt (Arg.some Arg.string) None info)

let format_term : output_format Term.t =
  let info =
    Arg.info [ "format" ]
      ~doc:
        "Output format. $(docv) is either $(b,text) (default, incremental) or \
         $(b,json) (batch mode, suitable for machine consumption)."
  in
  Arg.value (Arg.opt format_conv Text info)

let strict_term : bool Term.t =
  let info =
    Arg.info [ "strict" ]
      ~doc:
        "Exit with a nonzero code if any warning is emitted (see $(b,EXIT \
         STATUS))."
  in
  Arg.value (Arg.flag info)

let cmd_term =
  let combine chdir debug dune_root output_format query scan_root strict =
    let scan_root =
      match scan_root with
      | Some path when not (Filename.is_relative path) ->
          eprintf "Error: scan root must be a relative path: %s\n" path;
          exit exit_error
      | _ -> scan_root
    in
    (try
       run
         {
           query;
           scan_root;
           chdir;
           debug;
           dune_root;
           output_format;
           strict;
           use_color = use_color ();
         }
     with
    | Failure s | Sys_error s ->
        Ocamlgrep.error ~use_color:(use_color ()) s;
        exit exit_error
    | exn ->
        Ocamlgrep.error ~use_color:(use_color ()) (Printexc.to_string exn);
        exit exit_error)
  in
  Term.(
    const combine $ chdir_term $ debug_term $ dune_root_term
    $ format_term $ query_term $ scan_root_term $ strict_term
  )

(****************************************************************************)
(* Man page *)
(****************************************************************************)

let man : Manpage.block list =
  [
    `S Manpage.s_description;
    `P
      "Search a Dune project for OCaml code matching a structural pattern. \
       $(mname) walks the cmt files under $(b,_build/) and matches each typed \
       expression against $(b,PATTERN). The project's cmt files must be up to \
       date: run $(b,dune build @check) first.";
    `S "PATTERN SYNTAX";
    `I
      ( "$(b,__)",
        "Wildcard: matches any expression or record field." );
    `I
      ( "$(b,__1), $(b,__2), ...",
        "Numbered metavariables. All occurrences with the same number must \
         match structurally equal expressions." );
    `I
      ( "$(b,Foo), $(b,M.f)",
        "Identifiers are matched as a suffix of the fully qualified path: \
         $(b,f) matches $(b,Module.f), $(b,M.f) matches $(b,Outer.M.f). \
         Patterns are therefore robust to $(b,open) in the matched code." );
    `I
      ( "$(b,foo a b)",
        "In a function application any argument may be omitted. The special \
         forms $(b,foo ?arg:PRESENT) and $(b,foo ?arg:MISSING) enforce that an \
         optional argument is supplied or absent at the call site." );
    `I
      ( "$(b,(e : t))",
        "Type-constrained match: any expression matching $(b,e) whose inferred \
         type unifies with $(b,t). The wildcard $(b,__) is allowed in $(b,t)." );
    `I
      ( "$(b,match e with ...)",
        "Match arms and record fields are matched as a set, in any order. A \
         single clause in the pattern may match multiple clauses in the code." );
    `I
      ( "$(b,e.lid)",
        "Matches both reads ($(b,x.lid)) and writes ($(b,x.lid <- _)). \
         $(b,__.id) also matches record patterns, so $(b,__.foo) finds every \
         read, write, or pattern occurrence of field $(b,foo)." );
    `S "EXAMPLES";
    `Pre "$(mname) 'List.filter'";
    `Pre "$(mname) '(__ (__ : floatarray) : float array)'";
    `Pre "$(mname) 'List.rev __ @ __'";
    `Pre "$(mname) 'match __ with None -> __ | Some __1 -> Some __1'";
    `Pre "$(mname) 'List.fold_left __ __ (List.map __ __)'";
    `Pre "$(mname) 'Stdlib.max (__ : float) __'";
    `S "OUTPUT";
    `P
      "Each finding is printed as a header line giving the file and location \
       range, followed by the matched source lines with an \
       OCaml-compiler-style gutter:";
    `Pre
      "foo.ml:5:10-22:\n\
       5 |   let x = List.length xs\n\n\
       foo.ml:6:2-8:9:\n\
       6 |   match x with\n\
       7 |   | None -> None\n\
       8 |   | Some y -> Some y";
    `P
      "The matched range is highlighted in red unless the $(b,NO_COLOR) \
       environment variable is set (https://no-color.org/).";
    `S Manpage.s_exit_status;
    `P "$(b,0): one or more matches were found.";
    `P "$(b,1): no matches were found.";
    `P "$(b,2): an error occurred, or a warning occurred with $(b,--strict).";
    `S Manpage.s_bugs;
    `P "Report issues at https://github.com/LexiFi/ocamlgrep/issues.";
  ]

(****************************************************************************)
(* Entry point *)
(****************************************************************************)

let () =
  let info =
    Cmd.info "ocamlgrep" ~doc:"structural search for OCaml code" ~man
  in
  Cmd.v info cmd_term |> Cmd.eval |> exit
