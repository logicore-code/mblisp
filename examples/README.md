# Examples

Nine executable MoonBit packages, each demonstrating one slice of
the `mblisp` interpreter. Run any of them with:

```bash
moon run examples/<name> --target native
```

| Example | What it shows | Output |
|---|---|---|
| `factorial/`   | smallest end-to-end recursion                        | `720` |
| `fibonacci/`   | recursive `define` and arithmetic                    | `34` |
| `closures/`    | lexical environment capture (make-adder pattern)    | `18` |
| `higher_order/`| function composition (`compose`)                    | `26` |
| `list_ops/`    | user-defined `map` over the built-in list primitives | `(1 4 9 16 25)` |
| `y_combinator/`| the Church-style fixed-point combinator              | `120` |
| `hanoi/`       | tree recursion over a list of moves                 | `15` |
| `quicksort/`   | user-defined `filter` + recursive quicksort         | `(1 1 2 3 3 4 5 5 5 6 9)` |
| `lazy_streams/`| infinite streams via closures-as-thunks             | `(5 6 7 8 9 10 11 12)` |

Each `examples/<name>/` directory contains:

```
main.mbt     # the MoonBit wrapper that embeds a Scheme script
moon.pkg     # imports logicore-code/mblisp and marks the package executable
```

## How the wrappers are structured

Every example embeds the Scheme source as a multi-line `let src`
string and calls `eval_top`:

```moonbit
fn main {
  let src =
    #| (define (square x) (* x x))
    #| (square 7)
  let result = try @mblisp.eval_top(src) catch {
    err => { println("error: \{err}"); return }
  } noraise { v => v }
  println(result.to_string())
}
```

`eval_top` reads every top-level form in `src` and returns the
value of the last one, so the example scripts are written in the
natural top-down Scheme style: definitions first, expression to
print last.

## CI

The GitHub Actions workflow at `.github/workflows/ci.yml` runs
each example on every push so a regression in any primitive
operator fails the build immediately.