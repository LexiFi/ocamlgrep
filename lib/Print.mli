(** Format findings and more

    These functions are used by the [ocamlgrep] command.
*)

(** Format a finding for to be human-readable. *)
val finding : ?use_color:bool -> Match.finding -> string

(** Print a warning to stderr. *)
val warn : ?use_color:bool -> string -> unit

(** Print an error to stderr. *)
val error : ?use_color:bool -> string -> unit
