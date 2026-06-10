(** Structured access to the output of [dune describe workspace].

    Requires the [dune] command in PATH.

    This provides the locations of build assets (.ml, .cmt, ...) so that they
    can be scanned after a build. Files are listed based on dune's source and
    build rules; they may or may not exist depending on the build state.

    Building all cmt files can be done with:
    {[
      dune build @ check
    ]}
    which is slightly faster than a full [dune build].

    For a good example, cd into any Dune project and run
    [dune describe workspace]. *)

type module_ = {
  name : string;
  impl : string option;
  intf : string option;
  cmt : string option;
  cmti : string option;
}
(** A module described by dune.

    Example in sexp syntax as emitted by [dune describe workspace]:
    {v
        ((name Scan)
          (impl (_build/default/lib/Scan.ml))
          (intf (_build/default/lib/Scan.mli))
          (cmt (_build/default/lib/.ocamlgrep.objs/byte/ocamlgrep__Scan.cmt))
          (cmti (_build/default/lib/.ocamlgrep.objs/byte/ocamlgrep__Scan.cmti)))
    v}

    These are paths relative to the project root, not to the current directory.

    The [impl] and [intf] fields are paths to the ml and mli files before ppx
    preprocessing but after ocamllex or menhir preprocessing.

    [lexer.mll] appears in [impl] as [lexer.ml]. Similarly, [parser.mly] appears
    in [impl] as [parser.ml]. These ml files are not source files but they
    contain location directives such that normally, locations found cmt files
    refer the source mll or mly files.

    ppx preprocessing is set up differently: a unprocessed ml file appears as
    [impl]. The preprocessed ml file, typically a binary AST, is not given to us
    by [dune describe workspace] but it typically has a [.pp.ml] extension.

    Since Dune doesn't give the source file for the compilation unit, we have to
    use the locations embedded in the AST or in the typed tree. If the
    preprocessors did a good job, these locations should point to a source file.
    However, Dune operates on copies of source files such as
    [_build/default/lib/hello.ml] instead of the original [lib/hello.ml] that is
    the real source known to the user. The [_build/default] path is the
    [build_context] field provided by the root object of type {!t} and should be
    removed to recover the path to the master copy of the source file.

    Note that the paths to cmi files are not provided. They may be in the same
    folder as the cmt files but it may change from one version of Dune to
    another. *)

type library = {
  name : string;
  uid : string;
  local : bool;
      (** [true] for libraries defined in this project, [false] for external
          dependencies. *)
  requires : string list;
  source_dir : string;
  modules : module_ list;
  include_dirs : string list;
}
(** A library defined or used by the project *)

type executables = {
  names : string list;
  requires : string list;
  modules : module_ list;
  include_dirs : string list;
}
(** An [(executables ...)] entry. *)

type t = {
  root : string;  (** absolute path to project root *)
  build_context : string;  (** relative path, often "_build/default" *)
  libraries : library list;  (** libraries defined by the project *)
  executables : executables list;  (** executables defined by the project *)
}
(** A digested view of the workspace. *)

val describe :
  ?context:string ->
  ?dirs:string list ->
  ?root:string ->
  unit ->
  (t, string) result
(** [describe ?context ?dirs ?root ()] runs
    {[
      dune describe workspace -- format = csexp -- lang 0.1
    ]}
    and parses the output.

    The [--lang 0.1] pin is dune's stability contract: the format is kept stable
    across dune versions; new top-level entry types in a future [--lang] are
    silently ignored.

    @param context build context to describe (default: [default]).
    @param dirs
      restrict the description of the workspace to these folders. Their paths
      must be relative to the current folder (not to the project root).
    @param root force the project root instead of inferring it. *)

val get_modules : t -> module_ list
(** Extract all the compilation units *)

val filter_modules_under_dirs :
  t -> string list -> module_ list -> module_ list
(** [filter_modules_under_dirs workspace dirs modules] returns only modules
    that are located under one of the folders [dirs]. [dirs] must be relative
    paths.

    As of dune 3.22.2, [dune describe workspace ../lib] doesn't filter
    on ../lib as it's supposed to. This is a workaround where we do the
    filtering ourselves.
*)
