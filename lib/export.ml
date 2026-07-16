(* Auto-generated from "export.atd" by atdml. *)
[@@@ocaml.warning "-27-32-33-35-39"]

(** Types used for the JSON export *)

(* Inlined runtime — no external dependency needed. *)
module Atdml_runtime = struct
  (* Returns true iff the list has strictly more than [n] elements,
     without traversing past element n+1. *)
  let rec list_length_gt n = function
    | _ :: rest -> if n = 0 then true else list_length_gt (n - 1) rest
    | [] -> false

  module Yojson = struct
    let bad_type expected_type x =
      Printf.ksprintf failwith "expected %s, got: %s"
        expected_type (Yojson.Safe.to_string x)

    let bad_sum type_name x =
      Printf.ksprintf failwith "invalid variant for type '%s': %s"
        type_name (Yojson.Safe.to_string x)

    let missing_field type_name field_name =
      Printf.ksprintf failwith "missing field '%s' in object of type '%s'"
        field_name type_name

    let bool_of_yojson = function
      | `Bool b -> b
      | x -> bad_type "bool" x

    let yojson_of_bool b = `Bool b

    let int_of_yojson = function
      | `Int n -> n
      | x -> bad_type "int" x

    let yojson_of_int n = `Int n

    let float_of_yojson = function
      | `Float f -> f
      | `Int n -> Float.of_int n
      | x -> bad_type "float" x

    let yojson_of_float f = `Float f

    let string_of_yojson = function
      | `String s -> s
      | x -> bad_type "string" x

    let yojson_of_string s = `String s

    let unit_of_yojson = function
      | `Null -> ()
      | x -> bad_type "null" x

    let yojson_of_unit () = `Null

    let list_of_yojson f = function
      | `List xs -> List.map f xs
      | x -> bad_type "array" x

    let yojson_of_list f xs = `List (List.map f xs)

    let option_of_yojson f = function
      | `String "None" -> None
      | `List [`String "Some"; x] -> Some (f x)
      | x -> bad_type "option" x

    let yojson_of_option f = function
      | None -> `String "None"
      | Some x -> `List [`String "Some"; f x]

    let nullable_of_yojson f = function
      | `Null -> None
      | x -> Some (f x)

    let yojson_of_nullable f = function
      | None -> `Null
      | Some x -> f x

    let assoc_of_yojson f = function
      | `Assoc pairs -> List.map (fun (k, v) -> (k, f v)) pairs
      | x -> bad_type "object" x

    let yojson_of_assoc f xs =
      `Assoc (List.map (fun (k, v) -> (k, f v)) xs)
  end
end

(** position in a file *)
type position = {
  row: int;  (** zero-based line number *)
  column: int;  (** zero-based byte offset in a line *)
}

let create_position ~row ~column () : position =
  { row; column }

let position_of_yojson (x : Yojson.Safe.t) : position =
  match x with
  | `Assoc fields ->
    (* Duplicate JSON keys: behavior is unspecified (RFC 8259 §4 says keys SHOULD
       be unique). Below the threshold, List.assoc_opt returns the first binding;
       above it, the hashtable returns the last. *)
    let assoc_ =
      if Atdml_runtime.list_length_gt 5 fields then
        let tbl = Hashtbl.create 16 in
        List.iter (fun (k, v) -> Hashtbl.add tbl k v) fields;
        (fun key -> Hashtbl.find_opt tbl key)
      else (fun key -> List.assoc_opt key fields)
    in
    let row =
      match assoc_ "row" with
      | Some v -> Atdml_runtime.Yojson.int_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "position" "row"
    in
    let column =
      match assoc_ "column" with
      | Some v -> Atdml_runtime.Yojson.int_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "position" "column"
    in
    { row; column }
  | _ -> Atdml_runtime.Yojson.bad_type "position" x

let yojson_of_position (x : position) : Yojson.Safe.t =
  `Assoc (List.concat [
    [("row", Atdml_runtime.Yojson.yojson_of_int x.row)];
    [("column", Atdml_runtime.Yojson.yojson_of_int x.column)];
  ])

let position_of_json s =
  position_of_yojson (Yojson.Safe.from_string s)

let json_of_position x =
  Yojson.Safe.to_string (yojson_of_position x)

module Position = struct
  type nonrec t = position
  let create = create_position
  let of_yojson = position_of_yojson
  let to_yojson = yojson_of_position
  let of_json = position_of_json
  let to_json = json_of_position
end

type location = {
  file: string;
  start: position;
  end_: position;
}

let create_location ~file ~start ~end_ () : location =
  { file; start; end_ }

let location_of_yojson (x : Yojson.Safe.t) : location =
  match x with
  | `Assoc fields ->
    (* Duplicate JSON keys: behavior is unspecified (RFC 8259 §4 says keys SHOULD
       be unique). Below the threshold, List.assoc_opt returns the first binding;
       above it, the hashtable returns the last. *)
    let assoc_ =
      if Atdml_runtime.list_length_gt 5 fields then
        let tbl = Hashtbl.create 16 in
        List.iter (fun (k, v) -> Hashtbl.add tbl k v) fields;
        (fun key -> Hashtbl.find_opt tbl key)
      else (fun key -> List.assoc_opt key fields)
    in
    let file =
      match assoc_ "file" with
      | Some v -> Atdml_runtime.Yojson.string_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "location" "file"
    in
    let start =
      match assoc_ "start" with
      | Some v -> position_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "location" "start"
    in
    let end_ =
      match assoc_ "end" with
      | Some v -> position_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "location" "end"
    in
    { file; start; end_ }
  | _ -> Atdml_runtime.Yojson.bad_type "location" x

let yojson_of_location (x : location) : Yojson.Safe.t =
  `Assoc (List.concat [
    [("file", Atdml_runtime.Yojson.yojson_of_string x.file)];
    [("start", yojson_of_position x.start)];
    [("end", yojson_of_position x.end_)];
  ])

let location_of_json s =
  location_of_yojson (Yojson.Safe.from_string s)

let json_of_location x =
  Yojson.Safe.to_string (yojson_of_location x)

module Location = struct
  type nonrec t = location
  let create = create_location
  let of_yojson = location_of_yojson
  let to_yojson = yojson_of_location
  let of_json = location_of_json
  let to_json = json_of_location
end

type finding = {
  location: location;
  lines_before: string list;  (** optional lines of context before the match *)
  lines: string list;
  (**
     lines extracted from the range info without end-of-line markers. This
     is redundant as long as the original file remains available.
  *)
  lines_after: string list;  (** optional lines of context after the match *)
}

let create_finding ~location ?(lines_before = []) ~lines ?(lines_after = []) () : finding =
  { location; lines_before; lines; lines_after }

let finding_of_yojson (x : Yojson.Safe.t) : finding =
  match x with
  | `Assoc fields ->
    (* Duplicate JSON keys: behavior is unspecified (RFC 8259 §4 says keys SHOULD
       be unique). Below the threshold, List.assoc_opt returns the first binding;
       above it, the hashtable returns the last. *)
    let assoc_ =
      if Atdml_runtime.list_length_gt 5 fields then
        let tbl = Hashtbl.create 16 in
        List.iter (fun (k, v) -> Hashtbl.add tbl k v) fields;
        (fun key -> Hashtbl.find_opt tbl key)
      else (fun key -> List.assoc_opt key fields)
    in
    let location =
      match assoc_ "location" with
      | Some v -> location_of_yojson v
      | None -> Atdml_runtime.Yojson.missing_field "finding" "location"
    in
    let lines_before =
      match assoc_ "lines_before" with
      | None -> []
      | Some v -> (Atdml_runtime.Yojson.list_of_yojson Atdml_runtime.Yojson.string_of_yojson) v
    in
    let lines =
      match assoc_ "lines" with
      | Some v -> (Atdml_runtime.Yojson.list_of_yojson Atdml_runtime.Yojson.string_of_yojson) v
      | None -> Atdml_runtime.Yojson.missing_field "finding" "lines"
    in
    let lines_after =
      match assoc_ "lines_after" with
      | None -> []
      | Some v -> (Atdml_runtime.Yojson.list_of_yojson Atdml_runtime.Yojson.string_of_yojson) v
    in
    { location; lines_before; lines; lines_after }
  | _ -> Atdml_runtime.Yojson.bad_type "finding" x

let yojson_of_finding (x : finding) : Yojson.Safe.t =
  `Assoc (List.concat [
    [("location", yojson_of_location x.location)];
    [("lines_before", (Atdml_runtime.Yojson.yojson_of_list Atdml_runtime.Yojson.yojson_of_string) x.lines_before)];
    [("lines", (Atdml_runtime.Yojson.yojson_of_list Atdml_runtime.Yojson.yojson_of_string) x.lines)];
    [("lines_after", (Atdml_runtime.Yojson.yojson_of_list Atdml_runtime.Yojson.yojson_of_string) x.lines_after)];
  ])

let finding_of_json s =
  finding_of_yojson (Yojson.Safe.from_string s)

let json_of_finding x =
  Yojson.Safe.to_string (yojson_of_finding x)

module Finding = struct
  type nonrec t = finding
  let create = create_finding
  let of_yojson = finding_of_yojson
  let to_yojson = yojson_of_finding
  let of_json = finding_of_json
  let to_json = json_of_finding
end

type search_results = {
  findings: finding list;
  warnings: string list;
  error: string option;
}

let create_search_results ~findings ~warnings ?error () : search_results =
  { findings; warnings; error }

let search_results_of_yojson (x : Yojson.Safe.t) : search_results =
  match x with
  | `Assoc fields ->
    (* Duplicate JSON keys: behavior is unspecified (RFC 8259 §4 says keys SHOULD
       be unique). Below the threshold, List.assoc_opt returns the first binding;
       above it, the hashtable returns the last. *)
    let assoc_ =
      if Atdml_runtime.list_length_gt 5 fields then
        let tbl = Hashtbl.create 16 in
        List.iter (fun (k, v) -> Hashtbl.add tbl k v) fields;
        (fun key -> Hashtbl.find_opt tbl key)
      else (fun key -> List.assoc_opt key fields)
    in
    let findings =
      match assoc_ "findings" with
      | Some v -> (Atdml_runtime.Yojson.list_of_yojson finding_of_yojson) v
      | None -> Atdml_runtime.Yojson.missing_field "search_results" "findings"
    in
    let warnings =
      match assoc_ "warnings" with
      | Some v -> (Atdml_runtime.Yojson.list_of_yojson Atdml_runtime.Yojson.string_of_yojson) v
      | None -> Atdml_runtime.Yojson.missing_field "search_results" "warnings"
    in
    let error =
      match assoc_ "error" with
      | None | Some `Null -> None
      | Some v -> Some (Atdml_runtime.Yojson.string_of_yojson v)
    in
    { findings; warnings; error }
  | _ -> Atdml_runtime.Yojson.bad_type "search_results" x

let yojson_of_search_results (x : search_results) : Yojson.Safe.t =
  `Assoc (List.concat [
    [("findings", (Atdml_runtime.Yojson.yojson_of_list yojson_of_finding) x.findings)];
    [("warnings", (Atdml_runtime.Yojson.yojson_of_list Atdml_runtime.Yojson.yojson_of_string) x.warnings)];
    (match x.error with None -> [] | Some v -> [("error", Atdml_runtime.Yojson.yojson_of_string v)]);
  ])

let search_results_of_json s =
  search_results_of_yojson (Yojson.Safe.from_string s)

let json_of_search_results x =
  Yojson.Safe.to_string (yojson_of_search_results x)

module Search_results = struct
  type nonrec t = search_results
  let create = create_search_results
  let of_yojson = search_results_of_yojson
  let to_yojson = yojson_of_search_results
  let of_json = search_results_of_json
  let to_json = json_of_search_results
end

