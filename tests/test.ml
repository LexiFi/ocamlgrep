(** Test suite

    This is compiled into the test.exe executable.

    The current directory is initially the repo root. *)

open Printf

type finding = Ocamlgrep.finding

let print_warnings warnings =
  List.iter (fun msg -> eprintf "Warning: %s\n" msg) warnings

let print_findings findings =
  List.iter (fun x -> eprintf "%s" (Ocamlgrep.show_finding x)) findings

(* relative Windows path -> Unix path

   String.replace_all is only available starting with OCaml 5.5.
*)
let replace_backslashes src =
  let buf = Buffer.create (String.length src) in
  String.iter (function
    | '\\' -> Buffer.add_char buf '/'
    | c -> Buffer.add_char buf c
  ) src;
  Buffer.contents buf

let check_path path (finding : finding) =
  replace_backslashes finding.location.file = path

(** To simplify maintenance, we check only the value of the lines containing the
    finding. Specify a [check_details] function to test for more. *)
let test_ocamlgrep
    ?(check_details = fun _finding -> true)
    ?(dune_root = ".")
    ?(scan_root = ".")
    ?(tolerate_extra_findings = false)
    ?(before = 0)
    ?(after = 0)
    name query
    expected_findings =
  let test_func () =
    Testo.with_chdir (Fpath.v "tests/proj") @@ fun () ->
    eprintf "Query: %s\n" query;
    eprintf "Scan root: %s\n" scan_root;
    let { findings; warnings; error } : Ocamlgrep.search_results =
      Ocamlgrep.search ~dune_root ~scan_root ~before ~after [ query ]
    in
    eprintf "Warnings:\n";
    print_warnings warnings;
    eprintf "Findings:\n";
    print_findings findings;
    (match error with
    | Some msg -> Testo.fail ("ocamlgrep error: " ^ msg)
    | None -> ());
    List.iter (fun msg -> Ocamlgrep.warn msg) warnings;
    let remaining_findings =
      List.fold_left
        (fun remaining_findings expected_finding ->
          match
            List.find_opt
              (fun (x : finding) ->
                Ocamlgrep.matched x = expected_finding && check_details x)
              remaining_findings
          with
          | None ->
              Testo.fail
                ("missing finding:\n" ^ String.concat "\n" expected_finding)
          | Some finding -> List.filter (( != ) finding) remaining_findings)
        findings expected_findings
    in
    match remaining_findings with
    | [] -> ()
    | _ ->
        if not tolerate_extra_findings then (
          eprintf "We got unexpected extra findings:\n";
          print_findings remaining_findings;
          Testo.fail "unexpected extra findings")
  in
  Testo.create
    ~solo:"cannot run multiple 'dune describe workspace' commands in parallel"
    name test_func

let tests _env =
  [
    test_ocamlgrep "strings"
      ~scan_root:"lib/strings.ml"
      "(__ : string)"
      [ [ {|"a"|} ]; [ {|literal|} ]; [ {|"priv"|} ] ];
    test_ocamlgrep "type alias baseline"
      ~scan_root:"lib/alias_use.ml" "(__ : Alias_def.t)" [ [ "x" ] ];
    test_ocamlgrep "type alias" ~scan_root:"lib/alias_use.ml"
      "(__ : string)" [ [ "x" ] ];
    test_ocamlgrep "cppo preprocessing"
      ~scan_root:"lib/cppo_test.cppo.ml" {|"cppo_test"|}
      [ [ {|"cppo_test"|} ] ];
    test_ocamlgrep "symlinks"
      "duplicate"
      [ [ "duplicate" ]; [ "duplicate" ] ];
    test_ocamlgrep "non-symlink scan root"
      ~scan_root:"original"
      ~check_details:(check_path "original/main.ml")
      "duplicate"
      [ [ "duplicate" ] ];
    test_ocamlgrep "symlink scan root"
      ~scan_root:"symlink" "duplicate"
      ~check_details:(check_path "symlink/main.ml")
      [ [ "duplicate" ] ];
    test_ocamlgrep "preserve scan root"
      ~scan_root:"symlink" "duplicate"
      ~check_details:(check_path "symlink/main.ml")
      [ [ "duplicate" ] ];
    test_ocamlgrep "tuple type with holes"
      ~scan_root:"lib/types.ml"
      "(__ : _ * _)"
      [ [ {|(1, "hello")|} ] ];
    test_ocamlgrep "arrow type with holes"
      ~scan_root:"lib/types.ml"
      "(__ : _ -> _)"
      [ [ "string_of_int" ]; [ "fun s n -> String.length s = n" ] ];
    test_ocamlgrep "tuple type with specific first element"
      ~scan_root:"lib/types.ml"
      "(__ : int * _)"
      [ [ {|(1, "hello")|} ] ];
    (* strings.ml line 11: [  let priv = "priv"]
       line 9: [  type t = string]
       line 10: []
       line 12: [end] *)
    test_ocamlgrep "context before"
      ~scan_root:"lib/strings.ml"
      ~before:2
      ~check_details:(fun (f : finding) ->
        f.lines_before = ["  type t = string"; ""])
      {|"priv"|}
      [ [ {|"priv"|} ] ];
    test_ocamlgrep "context after"
      ~scan_root:"lib/strings.ml"
      ~after:1
      ~check_details:(fun (f : finding) ->
        f.lines_after = ["end"])
      {|"priv"|}
      [ [ {|"priv"|} ] ];
    test_ocamlgrep "context before and after"
      ~scan_root:"lib/strings.ml"
      ~before:1
      ~after:1
      ~check_details:(fun (f : finding) ->
        f.lines_before = [""] && f.lines_after = ["end"])
      {|"priv"|}
      [ [ {|"priv"|} ] ];
    test_ocamlgrep "applications written with |>, @@ or parentheses"
      ~scan_root:"lib/pipes.ml"
      "List.map (f __) __"
      [ [ "List.map (f 1) l" ];
        [ "l |> List.map (f 2)" ];
        [ "List.map (f 3) @@ l" ];
        [ "(List.map (f 4)) l" ] ];
    test_ocamlgrep "pattern written with |>"
      ~scan_root:"lib"
      "__ |> List.map (f __)"
      [ [ "List.map (f 1) l" ];
        [ "l |> List.map (f 2)" ];
        [ "List.map (f 3) @@ l" ];
        [ "(List.map (f 4)) l" ];
        [ "l |> List.map (Pipes.f 6)" ] ];
    test_ocamlgrep "pattern written with @@"
      ~scan_root:"lib/pipes.ml"
      "List.map (f __) @@ __"
      [ [ "List.map (f 1) l" ];
        [ "l |> List.map (f 2)" ];
        [ "List.map (f 3) @@ l" ];
        [ "(List.map (f 4)) l" ] ];
    test_ocamlgrep "locally defined |> is not an application"
      ~scan_root:"lib/local_pipe.ml"
      "List.map (Pipes.f __) __"
      [];
    test_ocamlgrep "user-defined operator"
      ~scan_root:"lib/pipes.ml"
      "__ >>= List.map (f __)"
      [ [ "l >>= List.map (f 5)" ] ];
    test_ocamlgrep "fun with one parameter"
      ~scan_root:"lib/functions.ml"
      "List.filter_map (fun __1 -> __1) __"
      [ [ "List.filter_map (fun x -> x) l" ] ];
    test_ocamlgrep "fun with two parameters"
      ~scan_root:"lib/functions.ml"
      "List.sort (fun __1 __2 -> compare __2 __1) __"
      [ [ "List.sort (fun a b -> compare b a) l" ] ];
    test_ocamlgrep "fun with two parameters, mismatch"
      ~scan_root:"lib/functions.ml"
      "List.sort (fun __1 __2 -> compare __1 __2) __"
      [];
    test_ocamlgrep "fun with the wrong number of parameters"
      ~scan_root:"lib/functions.ml"
      "List.sort (fun __ -> __) __"
      [];
    test_ocamlgrep "fun with a labeled parameter"
      ~scan_root:"lib/functions.ml"
      "(fun ~x __ -> __)"
      [ [ "(fun ~x y -> x - y)" ] ];
    test_ocamlgrep "fun with the wrong label"
      ~scan_root:"lib/functions.ml"
      "(fun x __ -> __)"
      [];
    test_ocamlgrep "function"
      ~scan_root:"lib/functions.ml"
      (* before OCaml 5.2, [function x -> e] and [fun x -> e] cannot be
         distinguished in the typed tree, so we use two clauses *)
      "List.filter_map (function None -> None | Some __ -> __) __"
      [ [ "List.filter_map (function Some x -> Some (x + 1) | None -> None) l" ] ];
    test_ocamlgrep "fun returning function"
      ~scan_root:"lib/functions.ml"
      "List.mapi (fun _ -> function __ -> __) __"
      [ [ "List.mapi (fun _ -> function Some x -> x | None -> 0) l" ] ];
  ]

let () = Testo.interpret_argv ~project_name:"ocamlgrep" tests
