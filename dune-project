(lang dune 3.18)
(name ocamlgrep)

(generate_opam_files true)

(license "MIT")
(source (github LexiFi/ocamlgrep))
(homepage "https://github.com/LexiFi/ocamlgrep")
(maintainers "Martin Jambon <martin@mjambon.com>")
(authors
  "Nicolás Ojeda Bär"
  "Martin Jambon"
)

(package
 (name ocamlgrep-lib)
 (synopsis "OCaml structural grep library")
 (depends
  (ocaml (and (>= 4.14) (< 4.15)))
  (dune (>= 3.18))
  csexp
 )
 (maintenance_intent "(latest)")
)

(package
 (name ocamlgrep)
 (synopsis "OCaml structural grep tool")
 (depends
  ocaml
  (dune (>= 3.18))
  (ocamlgrep-lib (= :version))

  ; Dependencies used for testing special build features
  (menhir :with-test)
  (ppx_deriving :with-test)
 )
 (maintenance_intent "(latest)")
)
