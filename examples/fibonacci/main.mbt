// Fibonacci example.
//
// Demonstrates recursive `define` and arithmetic. Computes the
// first few Fibonacci numbers and prints them.

///|
let src : String =
  #|
  #| (define (fib n)
  #|   (if (< n 2)
  #|       n
  #|       (+ (fib (- n 1)) (fib (- n 2)))))
  #|
  #| (fib 0)
  #| (fib 1)
  #| (fib 2)
  #| (fib 3)
  #| (fib 4)
  #| (fib 5)
  #| (fib 6)
  #| (fib 7)
  #| (fib 8)
  #| (fib 9)

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
