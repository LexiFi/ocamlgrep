(** File path utilities *)

(* TODO: use the Fpath.t type instead of string *)

(** Same as [Fpath.relativize] but fail with an exception.
    See also [relativize_dir]. *)
val relativize : root:string -> string -> string

(** Use this if you know the second argument is a folder even if it
    doesn't end with a slash. *)
val relativize_dir : root:string -> string -> string

(** Same as [Fpath.is_prefix]. Beware that this is syntactic
    i.e. [.] is not considered a prefix of [foo]. *)
val is_prefix : string -> string -> bool
