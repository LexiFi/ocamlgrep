
# Build the project.
# '@check' is for producing cmt files so we can run ocamlgrep on its codebase.
.PHONY: build
build:
	dune build @check

.PHONY: demo
demo: build
	dune exec -- ocamlgrep '(__ : Location.t)'

# Install opam dependencies
.PHONY: setup
setup:
	opam install --deps-only --with-test --with-doc \
	  ./ocamlgrep-lib.opam ./ocamlgrep.opam
