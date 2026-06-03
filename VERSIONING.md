Ocamlgrep Versioning
====================

Versioning scheme
-----------------

Ocamlgrep relies on the `compiler-libs` library that changes
frequently. To provide recent versions of Ocamlgrep for multiple
versions of OCaml, we maintain one branch per supported OCaml version.
For example, branch 502 is for OCaml 5.2. When releasing Ocamlgrep
version 0.1.0, we release one tarball for each OCaml version:
`ocamlgrep.0.1.0-414`, `ocamlgrep.0.1.0-500`, `ocamlgrep.0.1.0-501`, ...
Each opam package adds a constraint on `ocaml` such as
`"ocaml" {>= "5.3" & < "5.4"}` for `ocamlgrep.0.1.0-503`.
This allows users to request installations of `ocamlgrep` or a
`ocamlgrep.0.1.0` without having to worry about the compatibility with
OCaml.

Maintenance
-----------

Each Git branch named after the OCaml version (e.g. `503` for OCaml
5.3) is kept such that the difference with the main branch is minimal.

### Feature propagation

When new features are added to the main branch via one or more new
commits, these commits are cherry-picked onto each version branch.

The standard flow for adding a new feature is:

1. Review, approve, and merge pull request (squashed as one commit)
   into `main`.
2. For each version branch (e.g. `503`), cherry-pick the new commit(s)
   from `main` using `git cherry-pick` if possible or some other means
   and solve any conflicts.
3. Push and let CI check that everything compiles and works. Look for
   CI failures on the GitHub project page.
4. Fix the branches that fail to build. This will likely involve
   changing to an Opam switch for the relevant OCaml version.

### Upgrading the main branch to a new OCaml version

As soon as a new OCaml version is available from Opam, we should adopt
it as the default OCaml version, the version used by the main branch.

When adding support for OCaml 5.5, we proceed as follows:

1. Create persistent branch `504` as a copy of `main`.
2. Make the necessary changes for the main branch to compile with OCaml
   5.5 and pass the tests.
3. Edit the CI config file(s) to declare the new OCaml version we're
   testing. Optionally remove support for the oldest
   versions. Cherry-pick this change onto all version branches (see
   earlier section).
