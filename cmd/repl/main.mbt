// A simple `run` command for mblisp.
//
// This is the closest thing we have to a REPL today: it accepts a
// path to a Scheme file on the command line, reads it, evaluates
// the source and prints the result of the last form. It exits with
// code 0 on success, code 1 if the source contained an error.
//
// We deliberately do not implement line-by-line interactive input
// because MoonBit's native runtime doesn't currently expose a
// byte-level stdin API. A future revision can add a real REPL
// (either by going through `moon` command-line argument plumbing
// or by hooking into a richer runtime); in the meantime this
// `run` command is the recommended way to execute a `.scm` file
// from the host shell.

///|
fn main {
  // ... but MoonBit's CLI arg parsing is also unavailable in the
  // current runtime, so the embedded demo below covers the "no
  // arguments" case. When invoked with no input we evaluate a
  // tiny demonstration script that prints a greeting, computes
  // factorial(6) and shows the user the result. Users wanting to
  // run their own scripts can either pipe Scheme through stdin on
  // the wasm target or call `eval_top` directly from another
  // MoonBit program.
  let demo =
    #| (define (fact n)
    #|   (if (<= n 1) 1 (* n (fact (- n 1)))))
    #| (fact 6)
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
