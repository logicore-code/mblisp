# Changelog

All notable changes to `logicore-code/mblisp` are recorded here.
Versions follow Semantic Versioning: given a `MAJOR.MINOR.PATCH`
number, bump the

- `MAJOR` part on incompatible API changes
- `MINOR` part on new functionality in a backward-compatible way
- `PATCH` part on backward-compatible bug fixes

## [Unreleased]

### Added
- `letrec` for mutually-recursive local bindings. Sweeping-rebind
  approach: every marker allocated during value evaluation is
  re-pointed at the patched environment afterwards.
- Named `let` form: `(let name ((p1 v1) ...) body)` desugars
  into a recursive closure invocation.
- `examples/embed_demo/` — runnable mock router showing how to
  embed `mblisp` in another MoonBit program to evaluate
  runtime-supplied Scheme predicates.
- `perf/` package with real benchmark numbers using
  `moonbitlang/core/bench`. Numbers quoted in
  `docs/benchmark.md`.
- Native-vs-mblisp fib(20) overhead comparison: native
  ~20.5 µs/call vs interpreted ~34.6 ms/call (≈1700×). This
  is the headline number for "should I embed this?"; documented
  in `docs/benchmark.md` along with the caveats.
- 22 roundtrip / property-style tests in `roundtrip_test.mbt`.
- 5 benchmark tests in `perf/bench.mbt`.
- `examples/README.md` — catalogue of every bundled example.
- `docs/architecture.md` — data-flow diagram + design write-up.

### Docs
- README gets an honest "Caveat" subsection noting that
  MoonBit 0.1.20260915 doesn't expose user-defined `pub fn`s
  as named wasm exports — so a browser-side REPL is gated on a
  toolchain fix. The Node.js subprocess shim is mentioned as
  the realistic workaround.

### Fixed
- Plain-form `(define name expr)` is now recursive: a body may
  reference its own name (e.g. `(define ones (lambda () (cons 1
  ones)))`). Previously only the short-form
  `(define (name params...) body)` supported recursion.
- The pretty-printer now recognises `(quote x)` and prints it
  back as `'x` so reader → printer is a true round-trip.

### Changed
- `moon check` reports 0 warnings, 0 errors.
- The eval result shape is now `EvalResult::{ env, value }` so
  top-level forms can thread the updated environment across
  the call boundary.

## [0.2.0] — 2026-09-21

Adds `letrec`, named-let, the embed demo, the `perf/` package,
22 roundtrip tests, the new docs and an updated README. The
MoonBit module version is bumped because `eval`'s return type
changed from `SExp raise` to `EvalResult raise` — call sites
that previously took `(try eval(...))` need to update to
`(try eval(...) noraise { v => v.value })`.

## [0.1.0] — 2026-09-20

## [0.1.0] — 2026-09-20

Initial release. The first 24 commits land the interpreter core:

- `error.mbt`     — `ReadError`, `EvalError`, `ArityError` suberrors
- `sexp.mbt`      — `SExp` ADT with constructors and pretty-printer
- `reader.mbt`    — hand-written s-expression lexer / parser
- `env.mbt`       — persistent lexical environment
- `primitives