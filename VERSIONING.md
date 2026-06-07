Ocamlgrep Versioning
====================

Versioning scheme
-----------------

Ocamlgrep relies on the `compiler-libs` library that changes between
OCaml minor versions. To support multiple OCaml versions from a single
branch, version-specific code is isolated using
[cppo](https://github.com/ocaml-community/cppo), a C-preprocessor-like
tool for OCaml source files.

Source files that require version guards are named `*.ml.cppo` and use
directives like:

```ocaml
#if OCAML_VERSION >= (5, 2, 0)
  (* OCaml 5.2+ code *)
#else
  (* older code *)
#endif
```

The CI runs on all supported minor versions of OCaml every time a
commit is pushed to `main`.

Maintenance
-----------

All changes go to `main`. There are no version branches to maintain.

### Adding support for a new OCaml version

When a new OCaml version is released that changes `compiler-libs`:

1. Identify the API differences (diff typedtree.mli, parsetree.mli, etc.).
2. Add cppo guards in `lib/*.ml.cppo` for the new version boundary.
3. Add the new version to the matrix in `.circleci/config.yml`.
4. Update the `(ocaml (>= ...))` constraint in `dune-project` if needed.

### Releases

A release is a single `dune-release` flow on `main`. The opam package
constraint `(ocaml (>= 4.14))` covers all supported versions without
separate per-version packages.
