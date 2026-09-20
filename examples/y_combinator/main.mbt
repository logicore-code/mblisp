// Y combinator example.
//
// Demonstrates that the interpreter supports the call/cc-less
// fixed-point combinator: \`Y f = f(Y f)\`. We use \`Y\` to
// implement factorial without any explicit recursion in the
// body — the only "primitive recursion" lives inside the
// \`almost-fact\` helper that the combinator wires back to
// itself.

///|
let src : String =
  #|
  #| (define Y
  #|   (lambda (f)
  #|     ((lambda (x) (f (lambda (v) ((x x) v))))
  #|      (lambda (x) (f (lambda (v) ((x x) v)))))))
  #|
  #| (define fact
  #|   (Y (lambda (rec)
  #|        (lambda (n)
  #|          (if (<= n 1) 1 (* n (rec (- n 1))))))))
  #|
  #| (fact 5)

///|
fn main {
  let result = try @mblisp.eval_top(src) catch {
    err => {
      println("error: \{err}")
      return
    }
  } noraise {
    v => v
  }
  println(result.to_string())
}
