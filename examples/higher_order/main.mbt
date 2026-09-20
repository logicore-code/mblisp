// Higher-order functions example.
//
// Demonstrates composing first-class functions: \`compose f g\` is
// a function that, when applied to \`x\`, computes \`(f (g x))\`.
// We use it twice — once to compose \`square\` and \`inc\`, then
// to compose the result with another \`square\` — and verify the
// final result.

///|
let src : String =
  #|
  #| (define (compose f g)
  #|   (lambda (x) (f (g x))))
  #|
  #| (define (square x) (* x x))
  #| (define (inc x) (+ x 1))
  #|
  #| (define square-then-inc (compose inc square))
  #| (define inc-then-square (compose square inc))
  #|
  #| (+ (square-then-inc 3) (inc-then-square 3))

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
