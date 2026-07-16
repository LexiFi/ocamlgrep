## Working version

* Add flag `--no-messages` to suppress non-critical output (warnings, etc). Add
  flag `--no-color` to suppress color output. Add optional argument `-e PATTERN`
  to support more than one search pattern simultaneously.
  ([#24](https://github.com/LexiFi/ocamlgrep/pull/24)).

## 0.1.1 (2026-07-05)

* Fix the build so as to not require test-only dependencies for the
  main build ([#20](https://github.com/LexiFi/ocamlgrep/pull/20)).
* Add a `--dune-root` option that allows running ocamlgrep on a Dune
  project built with `--root` such as a test project within
  another Dune project ([#20](https://github.com/LexiFi/ocamlgrep/pull/20)).

## 0.1.0 (2026-07-04)

First release of ocamlgrep, formerly known as cmt_grep.
