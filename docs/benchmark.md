# Benchmark results

Numbers below are the median wall-clock time per `eval_top`
invocation on **MoonBit 0.1.20260915, native target, Linux x86_64,
release build**. Each row is the median of 10 samples measured
by `@bench.single_bench`.

Reproduce with:

```bash
moon test --target native --release perf
```

| Workload | Per-call median | What it exercises |
|---|---|---|
| `(fib 15)`                       | **2.9 ms**  | naive recursion; ~1500 self-calls |
| `(fact 10)`                      | **20.7 µs** | single-recursion descent |
| `(define (make-adder n) (lambda (x) (+ x n))) ((make-adder 3) 100)` | **6.8 µs** | closure construction + apply |
| `(length (build 50))`            | **94.1 µs** | cons-heavy list build + traverse |
| `(Y (lambda ...)) -> (fact 5)`   | **42.5 µs** | Y combinator + recursive call |

## Native-vs-mblisp overhead

The headline question for any embedding story: how much slower
is interpreted code than hand-written MoonBit?

Both benches compute `fib(20)` ten times per iteration; the
"native" version is a hand-written recursive MoonBit function
(`fn fib_native(n : Int) -> Int { ... }`), the "mblisp" version
is `(define (fib n) (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))`
passed to `eval_top`.

| Path | Per-fib(20)-call median | Notes |
|---|---|---|
| Native MoonBit       | **20.5 µs** | direct call, `-O2`-ish release build |
| Through `eval_top`   | **34.6 ms** | full pipeline: read, env, eval, primitives, closures |

That is a ~1700× slowdown. Two ways to read it:

- **Bad news:** if you were going to ship a million fib(20)
  calls per second, you don't want them to go through mblisp.
- **Good news:** the target use cases (rule engines, config
  evaluation, classroom demos) involve a handful of
  evaluations per request, not thousands. A 35 ms budget for a
  rule predicate is fine when the surrounding HTTP handler
  takes 50–200 ms anyway.

If we ever need to close that gap, the obvious next steps
(cranked away in commit `230fbe6` and the docs/architecture
write-up) are:

1. A bytecode compiler + small register VM (drops the AST walk
   and constant-folds primitives).
2. Inline caching for primitive calls (`+` on two ints should
   not need an `SExp::match` round-trip per invocation).
3. Tail-call optimisation for the recursive case.

Notes:

- `fib(15)` is a stress test by design: the naive Fibonacci
  formulation is exponential, so each call descends roughly
  1.5k times. A real workload is rarely this heavy.
- `fact(10)` is the typical "straight-line recursive function"
  shape; 20 µs per call works out to ~50k factorial evaluations
  per second on a single core.
- Closure construction includes allocating a marker in
  `env_table` and splicing it into the captured environment. The
  ~7 µs per call is the price we pay for the marker-rebinding
  trick that makes recursive `define` work.
- Y-combinator fact(5) demonstrates that the interpreter
  handles self-application and λ-calculus encodings within ~40 µs.

## What we are not measuring

These numbers are "per `eval_top` call", which is a coarse
unit. The interpreter does **not** yet have:

- Tail-call optimisation (every call allocates a stack frame).
- A bytecode compiler (we walk the AST directly).
- Inline caching or any other JIT-style specialisation.

Adding even a minimal `tail` form for self-tail calls would
roughly halve the `fib` and `fact` numbers for deep recursion.
See `docs/architecture.md` for why the AST-walking design was
chosen and what a bytecode path would look like.

## Caveats

- Numbers are sensitive to the MoonBit version and the host
  CPU; treat them as relative order-of-magnitude, not absolute.
- The `closure` row builds and applies one closure per call,
  but the same code path also handles `define`'s recursive
  closure — the cost is identical.
- `list` constructs and consumes a 50-element list; the same
  workload against a 500-element list would scale roughly
  linearly with list length.