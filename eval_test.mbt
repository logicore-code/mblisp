// eval_test.mbt
//
// Black-box tests for the evaluator. Each test parses a tiny Scheme
// program, evaluates it in a fresh global environment, and asserts
// the result.

///|
fn run(src : String) -> SExp raise {
  eval_top(src)
}

///|
test "eval_self_evaluating_numbers" {
  assert_eq(run("42"), SExp::int(42))
}

///|
test "eval_self_evaluating_strings" {
  assert_eq(run("\"hi\""), SExp::str("hi"))
}

///|
test "eval_self_evaluating_booleans" {
  assert_eq(run("#t"), SExp::bool_true())
  assert_eq(run("#f"), SExp::bool_false())
}

///|
test "eval_quote_returns_argument_unchanged" {
  assert_eq(run("'foo"), SExp::sym("foo"))
  assert_eq(
    run("'(1 2 3)"),
    SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:]),
  )
}

///|
test "eval_if_picks_then_branch" {
  assert_eq(run("(if #t 1 2)"), SExp::int(1))
}

///|
test "eval_if_picks_else_branch" {
  assert_eq(run("(if #f 1 2)"), SExp::int(2))
}

///|
test "eval_if_without_else_returns_nil" {
  assert_eq(run("(if #f 1)"), SExp::nil())
}

///|
test "eval_define_then_lookup" {
  assert_eq(run("(define x 42) x"), SExp::int(42))
}

///|
test "eval_lambda_application" {
  assert_eq(run("((lambda (x) (+ x 1)) 5)"), SExp::int(6))
}

///|
test "eval_lambda_two_arguments" {
  assert_eq(run("((lambda (x y) (* x y)) 3 4)"), SExp::int(12))
}

///|
test "eval_lambda_with_variadic_tail" {
  assert_eq(
    run("((lambda (x y . rest) (cons x (cons y rest))) 1 2 3 4)"),
    SExp::from_array(
      [SExp::int(1), SExp::int(2), SExp::int(3), SExp::int(4)][:],
    ),
  )
}

///|
test "eval_lambda_single_symbol_param_binds_whole_arg_list" {
  assert_eq(run("((lambda args (length args)) 1 2 3 4)"), SExp::int(4))
}

///|
test "eval_let_introduces_local_binding" {
  assert_eq(run("(let ((x 7) (y 8)) (+ x y))"), SExp::int(15))
}

///|
test "eval_letstar_makes_previous_bindings_visible" {
  assert_eq(run("(let* ((x 1) (y (* x 10))) (+ x y))"), SExp::int(11))
}

///|
test "eval_closure_captures_lexical_environment" {
  let src =
    #| (define make-adder (lambda (n) (lambda (x) (+ x n))))
    #| (define add3 (make-adder 3))
    #| (add3 7)
  assert_eq(run(src), SExp::int(10))
}

///|
test "eval_define_function_form" {
  assert_eq(run("(define (square x) (* x x)) (square 5)"), SExp::int(25))
}

///|
test "eval_recursion_via_define" {
  let src =
    #| (define (fact n)
    #|   (if (<= n 1) 1 (* n (fact (- n 1)))))
    #| (fact 6)
  assert_eq(run(src), SExp::int(720))
}

///|
test "eval_set_bang_updates_existing_binding" {
  let src =
    #| (define x 1)
    #| (set! x 99)
    #| x
  assert_eq(run(src), SExp::int(99))
}

///|
test "eval_cond_returns_first_matching_branch" {
  assert_eq(
    run("(cond ((= 1 2) 'no) ((= 1 1) 'yes) (else 'fallthrough))"),
    SExp::sym("yes"),
  )
}

///|
test "eval_cond_falls_through_to_else" {
  assert_eq(
    run("(cond ((= 1 2) 'no) (else 'fallthrough))"),
    SExp::sym("fallthrough"),
  )
}

///|
test "eval_begin_returns_last_expression" {
  assert_eq(run("(begin 1 2 3 4)"), SExp::int(4))
}

///|
test "eval_unbound_symbol_raises" {
  let raised : Bool = try {
    run("undefined-symbol") |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "eval_apply_non_callable_raises" {
  let raised : Bool = try {
    run("(1 2 3)") |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "eval_higher_order_function_with_closure" {
  let src =
    #| (define (compose f g) (lambda (x) (f (g x))))
    #| (define inc (lambda (n) (+ n 1)))
    #| (define square (lambda (n) (* n n)))
    #| ((compose square inc) 4)
  assert_eq(run(src), SExp::int(25))
}

///|
test "eval_nested_let_with_shadowing" {
  assert_eq(run("(let ((x 1)) (let ((x 2)) x))"), SExp::int(2))
}

///|
test "eval_truthiness_only_rejects_false" {
  assert_eq(run("(if 0 'truthy 'falsy)"), SExp::sym("truthy"))
  assert_eq(run("(if () 'truthy 'falsy)"), SExp::sym("truthy"))
  assert_eq(run("(if #f 'truthy 'falsy)"), SExp::sym("falsy"))
}

///|
test "eval_primitive_plus_chains_more_than_two_args" {
  assert_eq(run("(+ 1 2 3 4 5)"), SExp::int(15))
}
