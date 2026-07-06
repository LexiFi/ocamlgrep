OCAMLGREP = _build/install/default/bin/ocamlgrep

# Build the project.
.PHONY: build
build:
	ln -sf $(OCAMLGREP) .
	dune build @all @check

.PHONY: demo
demo:
	dune build @check
	$(OCAMLGREP) '(__ : Location.t)'

# This builds the test project(s) on which we run ocamlgrep.
# '@check' is to ensure we build all the cmt files.
.PHONY: test
test: build
	ln -sf _build/default/tests/test.exe test
	dune build
	./ocamlgrep true > /dev/null  # sanity check - some results expected
	dune runtest  # build the test executable
	cd tests/proj && dune build @check --root .  # build the cmt files
	./test

# Install all dependencies needed for development, including pre-commit hooks.
.PHONY: setup
setup:
	@if ! command -v pre-commit >/dev/null 2>&1; then \
	  echo "Error: pre-commit is not installed."; \
	  echo "Install it from https://pre-commit.com/#install"; \
	  exit 1; \
	fi
	opam install --deps-only --with-test --with-doc \
	  ./ocamlgrep-lib.opam ./ocamlgrep.opam
	opam install "ocamlformat.$(OCAMLFORMAT_VERSION)" -y
	pre-commit install

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
