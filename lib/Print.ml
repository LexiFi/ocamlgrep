(* Format findings and more *)

open Printf

type color = Yellow | Red | Green

let color ~use_color c fmt =
  if use_color then
    sprintf
      ("\027[1;%dm" ^^ fmt ^^ "\027[0m")
      (match c with
      | Yellow -> 33
      | Red -> 31
      | Green -> 32)
  else sprintf fmt

(* Highlight the substring [s.[lo..hi)] in red. Out-of-range indices
   are clamped silently - a stale cmt could in principle produce them
   even after the digest check, and crashing the renderer would be a
   poor failure mode. *)
let highlight_range ~use_color line lo hi =
  if use_color then
    let n = String.length line in
    let lo = max 0 (min n lo) in
    let hi = max lo (min n hi) in
    if lo = hi then line
    else
      String.sub line 0 lo
      ^ color ~use_color Red "%s" (String.sub line lo (hi - lo))
      ^ String.sub line hi (n - hi)
  else
    (* TODO: use carets to do the highlighting *)
    line

(* Format A: a header line giving the precise location, followed by
   the matched source lines with an OCaml-compiler-style [N |] gutter.

       foo.ml:5:10-22:
       5 |   let x = List.length xs

       foo.ml:6:10-8:9:
       6 |   let y =
       7 |     foo bar
       8 |       baz

   The header is unambiguous so consecutive findings need no
   separator between them. *)
let finding ?(use_color = true) (finding : Match.finding) =
  let color c fmt = color ~use_color c fmt in
  let start = finding.loc.loc_start in
  let end_ = finding.loc.loc_end in
  let file = color Green "%s" start.pos_fname in
  let start_line = start.pos_lnum in
  let start_col = start.pos_cnum - start.pos_bol in
  let end_line = end_.pos_lnum in
  let end_col = end_.pos_cnum - end_.pos_bol in
  let header =
    if start_line = end_line then
      sprintf "%s:%d:%d-%d:" file start_line start_col end_col
    else sprintf "%s:%d:%d-%d:%d:" file start_line start_col end_line end_col
  in
  let buf = Buffer.create 100 in
  bprintf buf "%s\n" header;
  let gutter_width = String.length (string_of_int end_line) in
  List.iteri
    (fun i line ->
      let lineno = start_line + i in
      let lo = if lineno = start_line then start_col else 0 in
      let hi = if lineno = end_line then end_col else String.length line in
      bprintf buf "%s | %s\n"
        (color Yellow "%*d" gutter_width lineno)
        (highlight_range ~use_color line lo hi))
    finding.lines;
  Buffer.contents buf

let warn ?(use_color = true) msg =
  eprintf "%s: %s\n%!" (color ~use_color Yellow "Warning") msg

let error ?(use_color = true) msg =
  eprintf "%s: %s\n%!" (color ~use_color Red "Error") msg
