# Changelog

All notable changes to `logicore-code/mblisp` are recorded here.
Versions follow Semantic Versioning: given a `MAJOR.MINOR.PATCH`
number, bump the

- `MAJOR` part on incompatible API changes
- `MINOR` part on new functionality in a backward-compatible way
- `PATCH` part on backward-compatible bug fixes

## [Unreleased]

### Fixed
- Plain-form `(define name expr)` is now recursive: a body may
  reference its own name (e.g. `(define ones (lambda () (cons 1 ones)))`).
  Previously only the short-form `(define (name params...) body)`
  supported recursion. (`eval.mbt`, commit `230fbe6`)

### Added
- New executable examples: `examples/hanoi/`,
  `examples/quicksort/`, `examples/lazy_streams/`.
- `docs/architecture.md` — data-flow diagram and design-decision
  write-up.
- `examples/README.md` — catalogue of all nine bundled examples
  with their expected output.
- `SUBMISSION.md` — one-page document for the hackathon
  submission form.

### Changed
- Dropped the old `PROPOSAL.md` in favour of `SUBMISSION.md`.
- `moon check` now reports 0 warnings, 0 errors (was 19 warnings).

## [0.1.0] — 2026-09-20

Initial release. The first 24 commits land the interpreter core:

- `error.mbt`     — `ReadError`, `EvalError`, `ArityError` suberrors
- `sexp.mbt`      — `SExp` ADT with constructors and pretty-printer
- `reader.mbt`    — hand-written s-expression lexer / parser
- `env.mbt`       — persistent lexical environment
- `primitives.mbt`— 27 built-in Scheme operators
- `eval.mbt`      — evaluator with special forms + primitive dispatch
- 89 unit tests across the six modules
- 6 executable examples:
  `factorial`, `fibonacci`, `closures`, `higher_order`,
  `list_ops`, `y_combinator`
- Apache-2.0 LICENSE
- `.github/workflows/ci.yml` — `moon check` + `moon test` + smoke
- `.githooks/pre-commit` — `moon check` on commit

The project replaces an earlier CRDT submission that overlapped
with several other MoonBit open-source entries."