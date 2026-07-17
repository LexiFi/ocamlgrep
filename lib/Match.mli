(** Type-aware structural search for OCaml code.

    This module implements the pattern matching engine for ocamlgrep. It
    searches the typed AST (.cmt files) of a Dune project for sub-expressions
    matching a given pattern.

    {2 Pattern syntax}

    A pattern is any valid OCaml expression. Special identifiers:

    - [__] matches any expression or record field.
    - [__1], [__2], ... are numbered metavariables: all occurrences with the
      same number must match the same (structurally equal) expression.
    - [(e : t)] matches expressions whose inferred type unifies with [t].

    Identifiers are matched as path suffixes: [f] matches [Module.f]. Match arms
    and record fields are matched as sets (order-independent).

    {2 Examples}

    {[
      List.filter __ __ (* all calls to List.filter *)
        (__ : int list) (* all expressions of type int list *)
        __1
      :: __1 (* cons cells with same head and tail *)
    ]} *)

exception Cannot_parse_type of exn

val matched : Export.finding -> string list
(** The matching lines where the leading matching bytes and the trailing
    matching bytes were removed. *)

val parse_query : string -> Parsetree.expression
(** [parse_query s] parses [s] as a single OCaml expression to be used as a
    pattern. Raises [Failure] with a human-readable message if [s] is not a
    valid OCaml expression. *)

val search :
  make_valid_source_path:(string -> string) ->
  before:int ->
  after:int ->
  Parsetree.expression list ->
  Cmt_format.cmt_infos ->
  Export.finding list
(** [search ~make_valid_source_path ~before ~after queries cmt] scans the typed
    tree in [cmt] for sub-expressions matching [queries] and returns matching
    locations. Matching lines are extracted from the source file.

    [make_valid_source_path] is in charge of rewriting project-relative
    source paths into valid paths that are desirable to the user (prefer
    relative paths starting with the scan root over absolute paths).

    [before] and [after] are the number of context lines to include before and
    after each match, populating [Export.finding.lines_before] and
    [Export.finding.lines_after].

    @raise Cannot_parse_type
*)
