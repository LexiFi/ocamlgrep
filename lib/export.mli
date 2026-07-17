(* Auto-generated from "export.atd" by atdml. *)

(** Types used for the JSON export *)

(** position in a file *)
type position = {
  row: int;  (** zero-based line number *)
  column: int;  (** zero-based byte offset in a line *)
}

val create_position : row:int -> column:int -> unit -> position
val position_of_yojson : Yojson.Safe.t -> position
val yojson_of_position : position -> Yojson.Safe.t
val position_of_json : string -> position
val json_of_position : position -> string

module Position : sig
  type nonrec t = position
  val create : row:int -> column:int -> unit -> t
  val of_yojson : Yojson.Safe.t -> t
  val to_yojson : t -> Yojson.Safe.t
  val of_json : string -> t
  val to_json : t -> string
end

type location = {
  file: string;
  start: position;
  end_: position;
}

val create_location : file:string -> start:position -> end_:position -> unit -> location
val location_of_yojson : Yojson.Safe.t -> location
val yojson_of_location : location -> Yojson.Safe.t
val location_of_json : string -> location
val json_of_location : location -> string

module Location : sig
  type nonrec t = location
  val create : file:string -> start:position -> end_:position -> unit -> t
  val of_yojson : Yojson.Safe.t -> t
  val to_yojson : t -> Yojson.Safe.t
  val of_json : string -> t
  val to_json : t -> string
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

val create_finding : location:location -> ?lines_before:string list -> lines:string list -> ?lines_after:string list -> unit -> finding
val finding_of_yojson : Yojson.Safe.t -> finding
val yojson_of_finding : finding -> Yojson.Safe.t
val finding_of_json : string -> finding
val json_of_finding : finding -> string

module Finding : sig
  type nonrec t = finding
  val create : location:location -> ?lines_before:string list -> lines:string list -> ?lines_after:string list -> unit -> t
  val of_yojson : Yojson.Safe.t -> t
  val to_yojson : t -> Yojson.Safe.t
  val of_json : string -> t
  val to_json : t -> string
end

type search_results = {
  findings: finding list;
  warnings: string list;
  error: string option;
}

val create_search_results : findings:finding list -> warnings:string list -> ?error:string -> unit -> search_results
val search_results_of_yojson : Yojson.Safe.t -> search_results
val yojson_of_search_results : search_results -> Yojson.Safe.t
val search_results_of_json : string -> search_results
val json_of_search_results : search_results -> string

module Search_results : sig
  type nonrec t = search_results
  val create : findings:finding list -> warnings:string list -> ?error:string -> unit -> t
  val of_yojson : Yojson.Safe.t -> t
  val to_yojson : t -> Yojson.Safe.t
  val of_json : string -> t
  val to_json : t -> string
end

