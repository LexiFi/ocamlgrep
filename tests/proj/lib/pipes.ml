(* Applications written in various ways *)

let f a b = a + b
let ( >>= ) x g = g x

let direct l = List.map (f 1) l
let revapply l = l |> List.map (f 2)
let apply l = List.map (f 3) @@ l
let partial l = (List.map (f 4)) l
let user_op l = l >>= List.map (f 5)
