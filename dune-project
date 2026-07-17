(lang dune 3.18)
(name ocamlgrep)

(generate_opam_files true)

(license "MIT")
(source (github LexiFi/ocamlgrep))
(homepage "https://github.com/LexiFi/ocamlgrep")
(maintainers "Martin Jambon <martin@mjambon.com>")
(authors
  "Edwin Ansari"
  "Nicolás Ojeda Bär"
  "Martin Jambon"
)

(package
 (name ocamlgrep-lib)
 (synopsis "OCaml structural grep library")
 (depends
  (ocaml (>= 4.14))
  (cppo :build)
  (csexp (>= 1.4.0))
  fpath
  (yojson (>= 3.0.0))
  (testo (and (>= 0.5.0) :with-test))
 )
 (maintenance_intent "(latest)")
)

(package
 (name ocamlgrep)
 (synopsis "OCaml structural grep tool")
 (depends
  ocaml
  (cmdliner (>= 1.1.0))
  (ocamlgrep-lib (= :version))

  ; Dependencies used for testing special build features
  (menhir :with-test)
  (ppx_deriving :with-test)
  (testo :with-test)
 )
 (maintenance_intent "(latest)")
)
