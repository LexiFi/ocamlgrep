(* Anonymous functions *)

let fun1 l = List.filter_map (fun x -> x) l
let fun2 l = List.sort (fun a b -> compare b a) l
let fun_labeled g = g ~cmp:(fun ~x y -> x - y)
let fun_cases l = List.mapi (fun _ -> function Some x -> x | None -> 0) l
let function_ l =
  List.filter_map (function Some x -> Some (x + 1) | None -> None) l
let nested l = List.sort (fun a -> fun b -> compare a b) l
let fun_function l = List.sort (fun a -> function b -> compare b a) l
let function1 l = List.map (function x -> x + 1) l
