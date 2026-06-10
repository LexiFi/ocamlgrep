(* This file is part of the ocamlgrep package.
   See the attached LICENSE file.
   Copyright (C) 2026 LexiFi *)

(*
   This is the only module exposed by the library.
*)

(** Type-aware search for OCaml expression patterns. *)

type position = {
  row : int;
  column : int;
}

type location = {
  file : string;
  start : position;
  end_ : position;
}

type finding = {
  location : location;
  lines : string list;
      (** Source lines spanned by [loc], from [loc_start.pos_lnum] to
          [loc_end.pos_lnum] inclusive. Always non-empty. *)
}
(** A region of source code that matched a query pattern. *)

type search_results = {
  findings: finding list;
  warnings: string list;
  error: string option;
}

type event =
  | Scan_module of string  (** a source file is about to be scanned *)
  | Finding of finding  (** a matching region was found *)
  | Warning of string  (** non-fatal diagnostic (e.g. missing cmt files) *)

val show_finding : ?use_color:bool -> finding -> string
(** Format a finding into human-readable text.

    @param use_color whether to emit ansiterm colors. Defaults to [true]. *)

(**/**)

val warn : ?use_color:bool -> string -> unit
val error : ?use_color:bool -> string -> unit

(* Extract the matching bytes from the list of matched lines (used in tests). *)
val matched : finding -> string list

(**/**)

val search :
  ?debug:bool -> ?root:string -> ?scan_root:string -> string -> search_results
(** [search query] searches the project containing the current directory for
    OCaml expressions matching the pattern [query].

    @param root forces the use of this folder as Dune's root folder.
    @param scan_root
      only scan this subtree which must be a folder or or a source file from
      which the OCaml module name can be derived by removing extensions and
      capitalization. *)

val incremental_search :
  ?debug:bool ->
  ?root:string ->
  ?scan_root:string ->
  (event -> unit) ->
  string ->
  (unit, string) result
(** Same as [search] but lets the caller report findings and warnings as they
    come rather than waiting for the end of the scan. *)

val to_json : search_results -> string
(** JSON export *)
