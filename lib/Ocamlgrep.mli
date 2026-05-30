(* This file is part of the ocamlgrep package.
   See the attached LICENSE file.
   Copyright (C) 2026 LexiFi *)

(*
   This is the only module exposed by the library.
*)

(** Type-aware search for OCaml expression patterns. *)

type location = {
  loc_start : Lexing.position;
  loc_end : Lexing.position;
  loc_ghost : bool;
}

type finding = {
  loc : location;
  lines : string list;
      (** Source lines spanned by [loc], from [loc_start.pos_lnum] to
          [loc_end.pos_lnum] inclusive. Always non-empty. *)
}
(** A region of source code that matched a query pattern. *)

type event =
  | Scan_module of string  (** a source file is about to be scanned *)
  | Finding of finding  (** a matching region was found *)
  | Warning of string  (** non-fatal diagnostic (e.g. missing cmt files) *)

val search :
  ?debug:bool ->
  ?root:string ->
  ?scan_root:string ->
  string ->
  (finding list * string list, string) result
(** [search ?root query] searches the Dune project rooted at [root] (or the
    project containing the current directory if [root] is omitted) for OCaml
    expressions matching the pattern [query].

    Returns [Ok ([], [])] immediately and silently if [root] is provided but
    does not contain a [dune-project] or [dune-workspace] file - this avoids
    creating a spurious [_build] directory.

    Returns [Ok (findings, warnings)] on success. Returns [Error message] for
    user-facing errors such as a bad query or a missing dune project. *)

val incremental_search :
  ?debug:bool ->
  ?root:string ->
  ?scan_root:string ->
  (event -> unit) ->
  string ->
  (unit, string) result
(** Same as [search] but lets the caller report findings and warnings as they
    come rather than waiting for the end of the scan. *)
