// Lazy streams example.
//
// Demonstrates that the interpreter can represent infinite streams
// of values using closures-as-thunks. Each "stream" is a pair
// `(head . thunk)` where calling the thunk returns the next pair.
// Because the thunk is only invoked when explicitly forced, the
// structure is lazily evaluated.
//
// We don't have a `delay`/`force` primitive yet, so the user has
// to apply the cdr-thunk by hand: `(car s)` gets the head,
// `((cdr s))` (i.e. apply the cdr as a function) gets the tail.
// That's slightly noisier than R5RS streams but works fine.

///|
let src : String =
  #|
  #| (define ones
  #|   (lambda () (cons 1 ones)))
  #|
  #| (define (take n s)
  #|   (if (= n 0)
  #|       '()
  #|       (cons (car s) (take (- n 1) ((cdr s))))))
  #|
  #| (define (nats-from k)
  #|   (lambda () (cons k (nats-from (+ k 1)))))
  #|
  #| (define (take-nats n k)
  #|   (take n ((nats-from k))))
  #|
  #| (take-nats 8 5)

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
