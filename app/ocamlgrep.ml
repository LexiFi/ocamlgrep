(* This file is part of the ocamlgrep package *)
(* See the attached LICENSE file.            *)
(* Copyright (C) 2000-2026 LexiFi            *)
(*
   Command-line interface and entry point for the 'ocamlgrep' command
*)

open Printf

type color =
  | Yellow
  | Red
  | Green

let color c fmt =
  sprintf
    ("\027[1;%dm" ^^ fmt ^^ "\027[0m")
    (match c with Yellow -> 33 | Red -> 31 | Green -> 32)

let warn msg =
  eprintf "%s: %s\n%!" (color Yellow "Warning") msg

let print_finding_with_color_range (finding : Ocamlgrep.Scan.finding) =
  let file_color = color Green "%s" finding.source in
  let i_color = color Yellow "%d" finding.i in
  let s_color =
    let len = String.length finding.s in
    if finding.c2 > len || finding.c1 > len then
      sprintf
        " Skipping this line with wrong indexes -- Maybe you should think about recompiling this file."
    else
      String.sub finding.s 0 finding.c1 ^
      color Red "%s" (String.sub finding.s finding.c1 (finding.c2-finding.c1)) ^
      String.sub finding.s finding.c2 (String.length finding.s - finding.c2)
  in
  printf "%s:%s:%s\n%!" file_color i_color s_color

let handle_event (ev: Ocamlgrep.Scan.event) =
  match ev with
  | Scan_file _path -> ()
  | Warning msg -> warn msg
  | Finding finding -> print_finding_with_color_range finding

let main () =
  let query = ref None in
  let usage_msg = "Usage: ocamlgrep <string>" in
  Arg.parse [] (fun s -> query := Some s) usage_msg;
  let paths =
    match Ocamlgrep.Paths.identify_dune_project () with
    | Error msg -> failwith msg
    | Ok paths -> paths
  in
  Ocamlgrep.Paths.init paths;
  match !query with
  | None -> Arg.usage [] usage_msg; exit 0
  | Some s -> Ocamlgrep.Scan.incremental_search paths handle_event s

let () =
  try
    main ()
  with exn ->
    let s =
      match exn with
      | Failure s | Sys_error s -> s
      | exn -> Printexc.to_string exn
    in
    eprintf "%s: %s\n%!" (color Red "Error") s;
    exit 1
