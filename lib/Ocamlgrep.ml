(* This file is part of the ocamlgrep package.
   See the attached LICENSE file.
   Copyright (C) 2026 LexiFi *)

open Printf

(*
   We reuse the location type defined by compiler-libs because there's no
   reason to define it differently.

   To expose a stable interface and make sure users of ocamlgrep-lib
   don't depend on compiler-libs interfaces, the type equation
   [location = Location.t] is omitted in the mli.
*)
type location = Location.t = {
  loc_start : Lexing.position;
  loc_end : Lexing.position;
  loc_ghost : bool;
}

type finding = Match.finding = { loc : location; lines : string list }
type event = Scan_module of string | Finding of finding | Warning of string

let show_finding ?use_color x = Print.finding ?use_color x
let matched finding = Match.matched finding
let warn ?use_color msg = Print.warn ?use_color msg
let error ?use_color msg = Print.error ?use_color msg

(*
   This allows transparently unwrapping Ok values:

   let/ unwrapped = give_me_a_result () in
   Ok (transform_further unwrapped)
*)
let ( let/ ) = Result.bind

(* Safe file path concatenation - same behavior as Fpath.(//) *)
let ( // ) a b = if Filename.is_relative b then Filename.concat a b else b

(* True when [dir] is the root of a Dune project.  We check for this before
   running 'dune describe workspace --root dir' to avoid creating a spurious
   _build directory in directories that are not Dune projects. *)
let is_dune_project_root dir =
  List.exists
    (fun f -> Sys.file_exists (dir // f))
    [ "dune-project"; "dune-workspace" ]

(*
   We gather up all the paths involved in the chain leading to the creation
   of a cmt file so we can troubleshoot easily.

   If the cmt file is missing or the digest of its input file
   couldn't be validated, or if anything else goes wrong, the error goes into
   the 'error' field.

   All paths are relative to the Dune project root.
*)
type cmt_diagnostics = {
  build_cmt_source_path : string;
      (* _build/default/src/a.ml
       or _build/default/src/a.pp.ml
       or _build/default/src/a__.ml-gen

       This is the input file of the compiler that produced the cmt file.
       We use it only to check the validity of the checksum found in the
       cmt file.

       This is not in general the source file or a copy of the source file.
       Location info found in the node of the AST or the typed tree is
       what gives us the source file names.
    *)
  build_cmt_path : string;
      (* _build/default/src/.a.objs/byte/a.cmt
       file containing the typed tree *)
  error : string option;
}

let show_nullable show = function
  | None -> "<none>"
  | Some x -> show x

let show_cmt_diagnostics (x : cmt_diagnostics) =
  sprintf "{ build_cmt_source_path: %s\n  build_cmt_path: %s\n  error: %s }"
    x.build_cmt_source_path x.build_cmt_path
    (show_nullable (fun s -> sprintf "%S" s) x.error)

(* Use this to build a valid file system path from a path that's relative
   to the project root.
   e.g. src/foo -> /path/to/src/foo
*)
let absolute_project_path (workspace : Dune_workspace.t) in_project_path =
  workspace.root // in_project_path

(* Use this to build a valid file system path from a path that's relative
   to the build space under the project root.
   e.g. src/foo -> /path/to/_build/default/src/foo
*)
let absolute_build_path (workspace : Dune_workspace.t) in_project_path =
  workspace.root // workspace.build_context // in_project_path

let check_ml_digest ws ~cmt_path ~cmt_sourcefile ~cmt_source_digest =
  match
    cmt_source_digest = Digest.file (absolute_build_path ws cmt_sourcefile)
  with
  | true -> Ok ()
  | false ->
      Error
        (sprintf
           "the checksum expected by the cmt file %S doesn't match the \
            checksum of the input file %S"
           cmt_path cmt_sourcefile)
  | exception Sys_error _ -> Error (sprintf "missing file %S" cmt_sourcefile)

(*
   Check the validity of a cmt file with respect to the compiler's input
   (.pp.ml or .ml). This uses info provided by 'dune describe workspace'
   but also inspects the file system for paths that are embedded in the
   cmt file.

   module_: info about one module from the Dune workspace
   cmd_sourcefile: "source" path extracted from the cmt file
   cmd_source_digest: MD5 checksum also extracted from the cmt file
*)
let resolve_cmt (workspace : Dune_workspace.t) ~cmt_path ~cmt_sourcefile
    ~cmt_source_digest : cmt_diagnostics =
  let error =
    match
      check_ml_digest workspace ~cmt_path ~cmt_sourcefile ~cmt_source_digest
    with
    | Ok () -> None
    | Error msg -> Some msg
  in
  { build_cmt_source_path = cmt_sourcefile; build_cmt_path = cmt_path; error }

(* We return Ok/Error for stats purposes only.
   Error messages are passed to the handler as they occur.

   Paths are kept relative to the workspace root as much as possible,
   converted only to valid file system paths when accessing the files.
*)
let process_one_cmt ?(debug = false) (workspace : Dune_workspace.t)
    (module_ : Dune_workspace.module_) handle_event query : (unit, unit) result
    =
  let warning msg = handle_event (Warning msg) in
  let/ cmt_path =
    (* path from the project root: _build/default/xxxxx *)
    Option.to_result ~none:() module_.cmt
  in
  match Cmt_format.read_cmt (absolute_project_path workspace cmt_path) with
  | {
      cmt_source_digest = Some cmt_source_digest;
      cmt_sourcefile = Some cmt_sourcefile;
      _;
    } as cmt -> (
      let paths =
        resolve_cmt workspace ~cmt_path ~cmt_sourcefile ~cmt_source_digest
      in
      if debug then eprintf "%s\n%!" (show_cmt_diagnostics paths);
      let/ () =
        match paths.error with
        | None -> Ok ()
        | Some msg ->
            warning msg;
            Error ()
      in
      handle_event (Scan_module module_.name);
      match
        Match.search ~make_valid_path:(absolute_build_path workspace) query cmt
      with
      | exception exn ->
          warning
            (Format.asprintf "error while analyzing %s: %a" cmt_path
               Location.report_exception exn);
          Error ()
      | results ->
          List.iter (fun r -> handle_event (Finding r)) results;
          Ok ())
  | { cmt_sourcefile = None; _ }
  | { cmt_source_digest = None; _ } ->
      Ok ()
  | exception Cmt_format.Error (Cmt_format.Not_a_typedtree _) ->
      warning (sprintf "error reading cmt file: %s" cmt_path);
      Error ()
  | exception Sys_error msg ->
      warning
        (sprintf "system error occurred while reading cmt file: %s: %s" cmt_path
           msg);
      Error ()

(* This initialization is needed to resolve type aliases. *)
let init_load_path (workspace : Dune_workspace.t) =
  let include_dirs =
    (* All the directories that may contain cmi files for local libraries,
       local executables, and external libraries used by the project.

       TODO: instead of a project-wide init, run an init per local library
       and per executable[s] to avoid confusion when two different
       compilation units have the same name?
    *)
    List.flatten [
      List.concat_map
        (fun (lib : Dune_workspace.library) -> lib.include_dirs)
        workspace.libraries;
      List.concat_map
        (fun (exe : Dune_workspace.executables) -> exe.include_dirs)
        workspace.executables;
      [Config.standard_library]
    ]
  in
  Load_path.init
    ~auto_include:Load_path.no_auto_include
    include_dirs

(* a.b.c -> a *)
let rec chop_extensions path =
  match Filename.extension path with
  | "" -> path
  | _ -> chop_extensions (Filename.chop_extension path)

(* a/b.c/de.f.g -> De *)
let module_name_of_path path =
  path
  |> Filename.basename
  |> chop_extensions
  |> String.capitalize_ascii

let filter_modules_by_name name modules =
  List.filter (fun (m : Dune_workspace.module_) -> m.name = name) modules

(** Generic incremental search. [search_fn] is called for each cmt file and
    should return a list of findings. [handle_event] accumulates state. *)
let incremental_search ?debug ?root ?scan_root (handle_event : event -> unit)
    query =
  let/ expr =
    match Parse.implementation (Lexing.from_string query) with
    | [ { Parsetree.pstr_desc = Pstr_eval (x, _); _ } ] -> Ok x
    | _ -> Error "Can only search for an expression."
    | exception _ -> Error "Could not parse search expression."
  in
  match root with
  | Some r when not (is_dune_project_root r) -> Ok ()
  | _ ->
      let module_name, dirs =
        (* request as little as possible from Dune - but if our scan root
           is a regular file, we have to pass its parent folder because
           Dune won't take regular files.
           Dune doesn't expose source files but we guess the module name
           from the file name and hope for the best. For example,
           "src/foo.mly" will query Dune for "src/" and we'll select
           module "Foo" from the results *)
        match scan_root with
        | None -> None, None
        | Some path ->
            if Sys.file_exists path && not (Sys.is_directory path) then
              let module_name = module_name_of_path path in
              Some module_name, None
            else
              None, Some [ Filename.dirname path ]
      in
      let/ workspace = Dune_workspace.describe ?root ?dirs () in
      init_load_path workspace;
      let modules = Dune_workspace.get_modules workspace in
      let modules =
        match module_name with
        | None -> modules
        | Some module_name -> filter_modules_by_name module_name modules
      in
      let total = List.length modules in
      let successes =
        List.fold_left
          (fun successes module_ ->
            match
              process_one_cmt ?debug workspace module_ handle_event expr
            with
            | Ok () -> successes + 1
            | Error () -> successes)
          0 modules
      in
      (if successes < total then
         let missing = total - successes in
         handle_event
           (Warning
              (sprintf
                 "%d/%d cmt files found, %d missing. Run 'dune build @check' \
                  to generate them (known bug: fails to build some cmts in \
                  vendored_dirs)"
                 successes total missing)));
      Ok ()

(* High-level search entry point for use by ocaml-lsp and similar tools. *)
let search ?debug ?root ?scan_root query =
  let findings = ref [] in
  let warnings = ref [] in
  let handle_event = function
    | Scan_module _ -> ()
    | Finding f -> findings := f :: !findings
    | Warning w -> warnings := w :: !warnings
  in
  let/ () = incremental_search ?debug ?root ?scan_root handle_event query in
  Ok (List.rev !findings, List.rev !warnings)
