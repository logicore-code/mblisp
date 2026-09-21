// Towers of Hanoi example.
//
// Recursive \`define\` over a 3-disk instance. The script prints the
// sequence of moves required to move the tower from peg A to peg C
// using peg B as scratch, plus the total move count.

let src : String =
  #|
  #| (define (move n from to via)
  #|   (if (= n 0)
  #|       '()
  #|       (append (move (- n 1) from via to)
  #|               (cons (list 'move from to)
  #|                     (move (- n 1) via to from)))))
  #|
  #| (move 3 'A 'C 'B)
  #|
  #| (define (length-acc xs acc)
  #|   (if (null? xs) acc (length-acc (cdr xs) (+ acc 1))))
  #|
  #| (define (len xs) (length-acc xs 0))
  #|
  #| (len (move 4 'A 'C 'B))

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