// Factorial example.
//
// Recursive \`define\` computing the factorial of 6. The result
// should be 720. Same machinery as the fibonacci example; kept as
// a separate executable so the README can link to the smallest
// possible self-contained script.

///|
let src : String =
  #|
  #| (define (fact n)
  #|   (if (<= n 1)
  #|       1
  #|       (* n (fact (- n 1)))))
  #|
  #| (fact 6)

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
