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
let test_ocamlgrep ?(check_details = fun _finding -> true)
    ?(scan_root = "tests/proj") ?(tolerate_extra_findings = false) name query
    expected_findings =
  let test_func () =
    eprintf "Query: %s\n" query;
    eprintf "Scan root: %s\n" scan_root;
    let { findings; warnings; error } : Ocamlgrep.search_results =
      Ocamlgrep.search ~scan_root query
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
    test_ocamlgrep "strings" ~scan_root:"tests/proj/lib/strings.ml"
      "(__ : string)"
      [ [ {|"a"|} ]; [ {|literal|} ]; [ {|"priv"|} ] ];
    test_ocamlgrep "type alias baseline"
      ~scan_root:"tests/proj/lib/alias_use.ml" "(__ : Alias_def.t)" [ [ "x" ] ];
    test_ocamlgrep "type alias" ~scan_root:"tests/proj/lib/alias_use.ml"
      "(__ : string)" [ [ "x" ] ];
    test_ocamlgrep "cppo preprocessing"
      ~scan_root:"tests/proj/lib/cppo_test.cppo.ml" {|"cppo_test"|}
      [ [ {|"cppo_test"|} ] ];
    test_ocamlgrep "symlinks"
      ~scan_root:"tests/proj" "duplicate"
      [ [ "duplicate" ]; [ "duplicate" ] ];
    test_ocamlgrep "non-symlink scan root"
      ~scan_root:"tests/proj/original"
      ~check_details:(check_path "tests/proj/original/main.ml")
      "duplicate"
      [ [ "duplicate" ] ];
    test_ocamlgrep "symlink scan root"
      ~scan_root:"tests/proj/symlink" "duplicate"
      ~check_details:(check_path "tests/proj/symlink/main.ml")
      [ [ "duplicate" ] ];
    test_ocamlgrep "preserve scan root"
      ~scan_root:"tests/proj/../proj/symlink" "duplicate"
      ~check_details:(check_path "tests/proj/../proj/symlink/main.ml")
      [ [ "duplicate" ] ];
  ]

let () = Testo.interpret_argv ~project_name:"ocamlgrep" tests
