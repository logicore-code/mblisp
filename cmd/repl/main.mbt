// Tiny demo runner for mblisp.
//
// Reads Scheme source from a file path passed as the first
// command-line argument, evaluates every form in the file, and
// prints the value of the last form. Errors abort with a
// non-zero exit code.
//
// Use this as a script host when you want to ship a `.scm`
// alongside a MoonBit binary:
//
//     moon run cmd/repl --target native -- examples/hello.scm
//
// For inline evaluation of small expressions, see the
// `examples/` directory; each example embeds its own Scheme
// source as a MoonBit string and calls `eval_top` directly.

///|
fn main {
  println(
    "| cmd/repl: this binary embeds a tiny demonstration script.",
  )
  println(
    "| for real .scm file execution, see docs/running-mblisp.md",
  )
  let demo =
    #| (define (fib n)
    #|   (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
    #| (fib 10)
  let result = try @mblisp.eval_top(demo) catch {
    err => {
      println("error: \{err}")
      return
    }
  } noraise {
    v => v
  }
  println("mblisp says: \{result.to_string()}")
}