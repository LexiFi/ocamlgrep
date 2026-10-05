## Working version

* Match applications written with `|>`, `@@` or explicit parentheses: in the
  code, `x |> f a`, `f a @@ x` and `(f a) x` are matched as `f a x`; in the
  pattern, `x |> f a` and `f a @@ x` match either an operator with the same
  name or `f a x`.
* Fix the matching of anonymous functions: patterns `fun p1 ... pn -> e`
  never matched, nor did patterns `function ...` with OCaml 5.2 and later.
  Functions are now matched one parameter at a time, labels included, so
  that `fun p1 p2 -> e` is equivalent to `fun p1 -> fun p2 -> e`, and
  `fun p -> e` to `function p -> e` (as was already the case for the typed
  tree before OCaml 5.2).
* Require cmdliner 2.0.0 or later, which is needed since 0.1.2 (`Term.env`).

## 0.1.2 (2026-10-05)

* Add options `-A`/`--after-context`, `-B/--before-context`, and
  `-C/--context` for printing lines of context before and after each
  match, similar to the same options found in grep
  ([#26](https://github.com/LexiFi/ocamlgrep/issues/26)).
* Add flag `--no-messages` to suppress non-critical output (warnings, etc). Add
  flag `--no-color` to suppress color output. Add optional argument `-e PATTERN`
  to support more than one search pattern simultaneously
  ([#24](https://github.com/LexiFi/ocamlgrep/pull/24)).

## 0.1.1 (2026-07-05)

* Fix the build so as to not require test-only dependencies for the
  main build ([#20](https://github.com/LexiFi/ocamlgrep/pull/20)).
* Add a `--dune-root` option that allows running ocamlgrep on a Dune
  project built with `--root` such as a test project within
  another Dune project ([#20](https://github.com/LexiFi/ocamlgrep/pull/20)).

## 0.1.0 (2026-07-04)

First release of ocamlgrep, formerly known as cmt_grep.
