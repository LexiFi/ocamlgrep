
# Build the project.
# '@check' is for producing cmt files so we can run ocamlgrep on its codebase.
.PHONY: build
build:
	dune build @check

.PHONY: demo
demo: build
	dune exec -- ocamlgrep '(__ : Location.t)'
