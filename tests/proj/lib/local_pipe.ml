(* A locally defined [|>], which is not the primitive of the standard library *)

let ( |> ) x g = List.rev (g x)

let local_revapply l = l |> List.map (Pipes.f 6)
