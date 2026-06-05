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

type finding = {
  loc : Location.t;
  lines : string list;
      (** Source lines spanned by [loc], from [loc_start.pos_lnum] to
          [loc_end.pos_lnum] inclusive. Always non-empty. *)
}

val matched : finding -> string list
(** The matching lines where the leading matching bytes and
    the trailing matching bytes were removed. *)

val parse_query : string -> Parsetree.expression
(** [parse_query s] parses [s] as a single OCaml expression to be used as a
    pattern. Raises [Failure] with a human-readable message if [s] is not a
    valid OCaml expression. *)

val search_cmt : Parsetree.expression -> Cmt_format.cmt_infos -> Location.t list
(** [search_cmt query cmt] scans the typed tree in [cmt] for sub-expressions
    matching [query] and returns matching locations. May raise
    [Cannot_parse_type]. *)

val search :
  make_valid_path:(string -> string) ->
  Parsetree.expression ->
  Cmt_format.cmt_infos ->
  finding list
(** same as [search_cmt] but extracts matching lines and puts them into the
    'finding' record.

    The [make_valid_path] function takes a source path as found in the locations
    of the cmt file and make it a valid filesystem path.

    In a Dune build, paths are relative to the build context (typically
    [<root>/_build/default]). Since our current working directory is different,
    we have to adjust the path to make it valid and successfully extract lines
    from the file. *)
