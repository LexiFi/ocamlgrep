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

.PHONY: clean
clean:
	git clean -dfX

# Update the opam files generated from 'dune-project'
.PHONY: opam-files
opam-files:
	opam exec -- dune build *.opam

# Attempt an automated release for the checked out branch.
# This flow must run for each OCaml version branch (e.g. '504' for OCaml 5.4).
# See VERSIONING.md for details.
.PHONY: opam-release
opam-release:
	dune-release tag
	dune-release distrib
	dune-release publish
	dune-release opam pkg
	dune-release opam submit
