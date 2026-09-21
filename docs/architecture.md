# Architecture

How the pieces of `mblisp` fit together.

## Data flow

```
  Scheme source text
        │
        │   read_one(src) ───── reader.mbt
        ▼
  SExp   ───────────────────── sexp.mbt (ADT)
        │
        │   eval_top(src, env~)
        ▼
  ┌────────────────────────────────────────────┐
  │              eval.mbt (eval/apply)         │
  │  ┌────────────┐    ┌────────────────────┐  │
  │  │  special   │    │  apply(proc, args) │  │
  │  │  forms:    │    │                    │  │
  │  │  quote/if/ │    │  primitive dispatch │  │
  │  │  define/   │    │  by symbol name    │  │
  │  │  set!/lam/ │    │  (primitives.mbt)  │  │
  │  │  let/cond/ │    │                    │  │
  │  │  begin     │    │  closure dispatch  │  │
  │  └────────────┘    │  by SExp shape     │  │
  │                    └────────────────────┘  │
  │                                            │
  │  closures = (params body . env_marker)     │
  │  env_marker -> env_table[Env]              │
  └────────────────────────────────────────────┘
        │
        ▼
  result : SExp   ── printed via to_string()
```

## Files

| File              | Responsibility                                    |
| ----------------- | ------------------------------------------------- |
| `error.mbt`       | `ReadError`, `EvalError`, `ArityError` suberrors  |
| `sexp.mbt`        | The `SExp` enum + constructors + pretty-printer   |
| `reader.mbt`      | Hand-written lexer/parser (`read_one`, `read_all`)|
| `env.mbt`         | Persistent lexical environment chain              |
| `primitives.mbt`  | 27 built-in Scheme operators                      |
| `eval.mbt`        | The evaluator (`eval`, `apply`, `eval_top`)       |

## Three things that matter

### 1. Persistent environments

`eval` returns `EvalResult::{ env, value }` so the caller can
thread the updated environment through a sequence of top-level
forms. This is what makes top-level scripts work:

```
(define x 10)   ─┐
                 ├─ each `define` returns a new env that
(define y 20)   ─┤  shadows the previous one's `env`.
                 │
(+ x y)        ──┘
```

The same pattern handles `set!`, `let`, `let*`, `cond`, `begin`
and the function short-form of `define`. Because each call
returns the env it just produced, the caller's loop can simply
feed it back into the next iteration.

### 2. Closures as data

A closure is encoded as a 3-cell SExp:

```
(params body . env_marker)
```

- `params` is the formal-parameter list (a proper list, a dotted
  pair `(x y . rest)`, or a bare symbol for the
  variadic-rest-as-list shape).
- `body` is the single expression to evaluate when the closure is
  applied.
- `env_marker` is a generated symbol like `__env__:42` that
  resolves to the captured `Env` via the global `env_table`.

Why not store the `Env` directly inside the SExp? Because `Env`
is a MoonBit struct — putting it inside an enum cell would force
the closure to own the environment, breaking sharing. Using a
marker indirection lets two closures capture the *same*
environment, and lets `define` patch the captured env to make a
function recursive.

### 3. Marker rebinding for recursive `define`

`(define (fact n) (if (<= n 1) 1 (* n (fact (- n 1)))))`

When this is evaluated:

1. Allocate a fresh marker `m`.
2. Build the closure `(params body . m)` with `m` pointing at
   the *current* `env`.
3. Bind `fact` to that closure in `env`, producing `env'`.
4. **Re-point** `m` at `env'`.

After step 4, the closure's marker resolves to an environment
that contains the closure itself under the name `fact`. When the
body recurses, `(fact ...)` finds the binding and the cycle
terminates.

The same trick is used for `(define name expr)` plain form after
the recursive-define fix in commit `230fbe6`.

## Reserved keywords

MoonBit 0.1.20260915 reserves the identifiers `extend`, `define`
and `set` for future language use. To stay forward-compatible we
have renamed the MoonBit-side methods that would otherwise
collide:

| Scheme form  | MoonBit method |
| ------------ | -------------- |
| (child frame)| `Env::child`   |
| (bind name)  | `Env::bind`    |
| (set! name)  | `Env::assign`  |

Scheme-side `define` and `set!` are matched by *symbol name*
inside `eval_pair`, not as MoonBit keywords, so the Scheme
syntax is unchanged.

## Why not a bytecode VM?

For an interpreter that fits in 1.6k lines of code, an AST-walking
implementation is dramatically simpler to reason about and debug.
The performance budget for the intended use cases (config files,
rules engines, embedded DSLs, classroom demos) is well within what
the direct evaluator delivers. A future revision might add a
bytecode compiler + register VM; until then the current
implementation is the right level of abstraction for what we
need.