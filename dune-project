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
  (ocaml (and (>= 5.4) (< 5.5)))
  (dune (>= 3.18))
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
 )
 (maintenance_intent "(latest)")
)
