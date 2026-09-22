# mblisp

A pure-MoonBit implementation of a small Scheme/Lisp interpreter, plus a few
example programs that exercise the interpreter end-to-end. The project is
self-contained: the only external dependencies are the MoonBit standard
library (`moonbitlang/core` for `ref` and `hashmap`).

## Why this exists

`mblisp` was created for the **MoonBit September 2026 Open Source Competition**
as a replacement for an earlier CRDT submission. The CRDT direction turned out
to overlap with several other entries (notably `Juwan-Hwang/moon-certified` and
`dowdiness/event-graph-walker`), so we switched to a project that is more
clearly *ours* — a from-scratch Scheme interpreter written entirely in MoonBit.

## Project layout

```
logicore-code/mblisp/
├── moon.mod / moon.pkg     # Module + package manifest
├── error.mbt               # ReadError / EvalError / ArityError
├── sexp.mbt                # SExp ADT + constructors + pretty-printer
├── reader.mbt              # Lexer / parser for s-expressions
├── env.mbt                 # Persistent lexical environment
├── primitives.mbt          # 27 built-in Scheme operators
├── eval.mbt                # Eval/apply core, returns (env, value)
├── eval_test.mbt / *_test.mbt  # 89 unit tests
├── cmd/repl/main.mbt       # Demo runner that embeds and runs Scheme
├── examples/               # Six runnable Scheme-as-MoonBit examples
│   ├── factorial/
│   ├── fibonacci/
│   ├── closures/
│   ├── higher_order/
│   ├── list_ops/
│   └── y_combinator/
├── .github/workflows/ci.yml  # CI: check + test + examples
├── .githooks/pre-commit      # `moon check` on commit
├── AGENTS.md               # Build / test commands for agents
├── LICENSE                 # Apache-2.0
└── README.md               # You are here
```

## Architecture

```
   source string
        │
        ▼
   reader.mbt ─── read_one / read_all
        │
        ▼
   sexp.mbt  ─── SExp ADT (Num | Str | Sym | Bool | Nil | Cons)
        │
        ▼
   eval.mbt  ─── eval(expr, env) → (env, value)
        │            │
        │            ├─ primitives.mbt (dispatched by symbol name)
        │            └─ env.mbt (chain of immutable Env records)
        ▼
   printed by to_string()
```

### Notable design choices

- **Persistent environments.** `eval` returns `EvalResult::{ env, value }` so
  the caller can thread the updated environment through a sequence of
  top-level forms. `define`, `set!`, `let`, `let*`, `cond`, `begin` and the
  function short-form of `define` all flow through the same threading model.
- **Closures as data.** A closure is encoded as `(params body . env_marker)`
  where `env_marker` is a symbol that resolves to the captured `Env` via a
  global registry. `define` patches the marker after the closure is
  constructed so that the function body can refer to itself recursively.
- **Native MoonBit types.** `SExp` is a closed enum, `Env` is a record with a
  `HashMap` for local bindings, errors are `suberror` variants. No external
  crates; nothing depending on a VM.
- **Reserved-keyword avoidance.** MoonBit 0.1.20260915 reserves `extend`,
  `define` and `set`, so the Scheme-side `define` is matched by symbol name
  inside `eval_pair` (not by treating it as a keyword) and the MoonBit-side
  methods that would collide were renamed: `Env::extend` → `Env::child`,
  `Env::define` → `Env::bind`.

### Caveat: MoonBit wasm / JS interop in 0.1.20260915

The interpreter itself compiles cleanly for `wasm`, `wasm-gc`,
`js`, and `native`. However, this MoonBit version doesn't
expose a `pub fn` as a named wasm export — the only wasm
exports are the internal `moonbit.*` runtime helpers. So a
browser-side REPL that "just calls `mblisp.eval_top(src)` from
JS" isn't a few lines away; you either need to host the
wasm through WASI (for stdin/stdout-style I/O) or wait for the
MoonBit toolchain to expose user functions across the JS
bridge.

What works today on every target is the MoonBit-side embed
(see `examples/embed_demo/`), which is what this repository
documents. A follow-up could ship a small Node.js REPL that
spawns the native binary as a subprocess; that's a 30-line
script rather than a toolchain fix.

## Quick start

The interpreter library is `logicore-code/mblisp`. The simplest program that
uses it:

```moonbit
import { "logicore-code/mblisp" }

fn main {
  let src =
    #| (define (fact n)
    #|   (if (<= n 1) 1 (* n (fact (- n 1)))))
    #| (fact 5)
  let v = try @mblisp.eval_top(src) catch { err => { println(err.to_string()); return } } noraise { v => v }
  println(v.to_string())
}
```

## Building / testing

```bash
# Unit tests (94 cases: sexp, reader, env, primitives, eval,
# plus named-let / letrec coverage)
moon test

# Performance benchmarks (median wall-clock per eval_top call).
# Numbers are recorded in docs/benchmark.md.
moon test --target native --release perf

# Type-check the library and all examples
moon check

# Auto-format
moon fmt

# Run any example
moon run examples/factorial     --target native
moon run examples/fibonacci     --target native
moon run examples/closures      --target native
moon run examples/list_ops      --target native
moon run examples/higher_order  --target native
moon run examples/y_combinator  --target native
moon run examples/hanoi         --target native
moon run examples/quicksort     --target native
moon run examples/lazy_streams  --target native
moon run cmd/repl               --target native
moon run embed_demo             --target native
```

The examples each embed a tiny Scheme script, run it via `eval_top` and print
the value of the last form.

## License

Apache-2.0. See `LICENSE` for the full text.

## How this fits in the MoonBit ecosystem

`mblisp` is one of the few pure-MoonBit-language projects that
tries to be **useful in other MoonBit projects**, rather than
just being a thing that exists. Three specific angles:

- **DSL embedder for MoonBit apps.** A MoonBit backend service
  that wants to expose runtime-configurable business rules can
  embed `mblisp` and let the ops team write the rules in Scheme.
  See `examples/embed_demo/` for a runnable mock-routing-rules
  demo.
- **Reference interpreter for MoonBit learners.** `eval.mbt`
  walks through every special form by hand. Anyone learning
  MoonBit can read it and see idiomatic uses of `match`,
  `suberror`, `HashMap`, `Ref`, `derive(Debug)`, and `try` /
  `catch` / `noraise`.
- **wasm-friendly.** The interpreter compiles to `wasm` /
  `wasm-gc` / `js` / `native` with zero source changes. A
  wasm-built interpreter can run inside a browser tab without
  pulling in JavaScript glue (see `moon build --target wasm`).

Benchmarks (median wall-clock per `eval_top` call, native release
build, see `docs/benchmark.md` for caveats):

| Workload | Time |
|---|---|
| `(fib 15)`             | 2.9 ms   |
| `(fact 10)`            | 20.7 µs  |
| closure construction   | 6.8 µs   |
| 50-element list ops    | 94.1 µs  |
| Y combinator fact(5)   | 42.5 µs  |