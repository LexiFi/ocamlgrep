(* File path utilities *)

(* TODO: use the Fpath.t type instead of string *)

open Printf

let relativize ~root:a b =
  match Fpath.relativize ~root:(Fpath.v a) (Fpath.v b) with
  | Some path -> Fpath.to_string path
  | None ->
      (* the arguments must be both absolute paths or both relative paths *)
      ksprintf invalid_arg "internal error: relativize(%s, %s)" a b

let relativize_dir ~root b =
  if root = b then
    (* we know it's a folder but Fpath doesn't know unless we append
       slashes that must be removed later *)
    "."
  else
    relativize ~root b

let is_prefix a b =
  Fpath.is_prefix (Fpath.v a) (Fpath.v b)
