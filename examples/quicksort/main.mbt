// Quicksort example.
//
// Standard list quicksort using only `car`/`cdr`/`cons` and the
// built-in primitives. Sorts a list and prints the result.

///|
let src : String =
  #|
  #| (define (filter pred xs)
  #|   (if (null? xs)
  #|       '()
  #|       (if (pred (car xs))
  #|           (cons (car xs) (filter pred (cdr xs)))
  #|           (filter pred (cdr xs)))))
  #|
  #| (define (qsort xs)
  #|   (if (null? xs)
  #|       '()
  #|       (let ((pivot (car xs)) (rest (cdr xs)))
  #|         (append (qsort (filter (lambda (x) (< x pivot)) rest))
  #|                 (cons pivot (qsort (filter (lambda (x) (>= x pivot)) rest)))))))
  #|
  #| (qsort (list 3 1 4 1 5 9 2 6 5 3 5))

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
