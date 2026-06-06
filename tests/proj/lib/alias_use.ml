(* [Alias_def.t] is an alias for [string].
   We want to make sure that searching for [(__ : string)] returns
   the expression [x] below.
*)
let use_string_alias (x : Alias_def.t) = x
