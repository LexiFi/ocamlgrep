(* This file is part of the ocamlgrep package.
   See the attached LICENSE file.
   Copyright (C) 2026 LexiFi *)

(** Type-aware search for OCaml expression patterns. *)

type event =
  | Scan_file of string  (** a source file is about to be scanned *)
  | Finding of Match.finding  (** a matching region was found *)
  | Warning of string  (** non-fatal diagnostic (e.g. missing cmt files) *)

val search : string -> (Match.finding list * string list, string) result
(** [search query] searches the local Dune project for OCaml expressions
    matching the pattern [query].

    Returns [Ok (findings, warnings)] on success. Returns [Error message] for
    user-facing errors such as a bad query or a missing dune project. *)

val incremental_search : (event -> unit) -> string -> (unit, string) result
(** Same as [search] but lets the caller report findings and warnings as they
    come rather than waiting for the end of the scan. *)
