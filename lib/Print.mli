(** Format findings and more

    These functions are used by the [ocamlgrep] command. *)

val finding : ?use_color:bool -> Export.finding -> string
(** Format a finding for to be human-readable. *)

val warn : ?use_color:bool -> string -> unit
(** Print a warning to stderr. *)

val error : ?use_color:bool -> string -> unit
(** Print an error to stderr. *)
