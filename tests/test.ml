(** Test suite

    This is compiled into the test.exe executable.

    The current directory is initially the repo root. *)

open Printf

type finding = Ocamlgrep.finding

let print_warnings warnings =
  List.iter (fun msg -> eprintf "Warning: %s\n" msg) warnings

let print_findings findings =
  List.iter (fun x -> eprintf "%s" (Ocamlgrep.show_finding x)) findings

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
  ]

let () = Testo.interpret_argv ~project_name:"ocamlgrep" tests
