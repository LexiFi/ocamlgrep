OCAMLGREP = _build/install/default/bin/ocamlgrep

# Build the project.
.PHONY: build
build:
	ln -sf $(OCAMLGREP) .
	dune build app/ocamlgrep.exe

.PHONY: demo
demo:
	dune build @check
	$(OCAMLGREP) '(__ : Location.t)'

# This builds the test project(s) on which we run ocamlgrep.
# '@check' is to ensure we build all the cmt files.
.PHONY: test
test:
	dune build @check
	$(OCAMLGREP) '__' --strict

# Install opam dependencies
.PHONY: setup
setup:
	opam install --deps-only --with-test --with-doc \
	  ./ocamlgrep-lib.opam ./ocamlgrep.opam
