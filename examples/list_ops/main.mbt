// List operations example.
//
// Demonstrates the built-in list primitives (\`cons\`, \`car\`,
// \`cdr\`, \`list\`, \`length\`, \`append\`, \`reverse\`) on a small
// sample list and a few user-defined helpers.

let src : String =
  #|
  #| (define xs (list 1 2 3 4 5))
  #|
  #| (length xs)
  #| (car xs)
  #| (cdr xs)
  #| (reverse xs)
  #| (append xs (list 6 7 8))
  #|
  #| (define (map f lst)
  #|   (if (null? lst)
  #|       '()
  #|       (cons (f (car lst)) (map f (cdr lst)))))
  #|
  #| (define (square x) (* x x))
  #|
  #| (map square xs)

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