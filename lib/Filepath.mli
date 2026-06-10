(** File path utilities *)

(* TODO: use the Fpath.t type instead of string *)

val relativize : root:string -> string -> string
val relativize_dir : root:string -> string -> string
val is_prefix : string -> string -> bool
