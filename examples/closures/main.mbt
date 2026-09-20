// Closures example.
//
// Demonstrates that closures capture the lexical environment they
// were defined in, not the one they are called in. We define a
// `make-adder` factory and call it twice with different `n`s; the
// two resulting closures are independent and remember their own
// capture.

///|
let src : String =
  #|
  #| (define (make-adder n)
  #|   (lambda (x) (+ x n)))
  #|
  #| (define add2 (make-adder 2))
  #| (define add10 (make-adder 10))
  #|
  #| (+ (add2 3) (add10 3))

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
