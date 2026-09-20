// sexp_test.mbt
//
// Black-box tests for the S-expression data type and its pretty-printer.

///|
test "num_to_string_round_trip" {
  assert_eq(SExp::int(42).to_string(), "42")
  assert_eq(SExp::num(3.14).to_string(), "3.14")
}

///|
test "string_escapes_quote_and_backslash" {
  let s = SExp::str("hello \"world\" \\path")
  assert_eq(s.to_string(), "\"hello \\\"world\\\" \\\\path\"")
}

///|
test "nil_renders_as_empty_parens" {
  assert_eq(SExp::nil().to_string(), "()")
}

///|
test "bool_renders_as_hash_literal" {
  assert_eq(SExp::bool_true().to_string(), "#t")
  assert_eq(SExp::bool_false().to_string(), "#f")
}

///|
test "list_renders_with_parens" {
  let l = SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:])
  assert_eq(l.to_string(), "(1 2 3)")
}

///|
test "nested_list_renders_recursively" {
  let l = SExp::from_array([
    SExp::from_array([SExp::int(1), SExp::int(2)][:]),
    SExp::from_array([SExp::int(3), SExp::int(4)][:]),
  ])
  assert_eq(l.to_string(), "((1 2) (3 4))")
}

///|
test "dotted_pair_renders_with_dot" {
  let p = SExp::cons(SExp::int(1), SExp::int(2))
  assert_eq(p.to_string(), "(1 . 2)")
}

///|
test "improper_list_renders_with_dot_at_end" {
  let improper = SExp::cons(
    SExp::int(1),
    SExp::cons(SExp::int(2), SExp::int(3)),
  )
  assert_eq(improper.to_string(), "(1 2 . 3)")
}

///|
test "to_array_round_trip_on_proper_list" {
  let l = SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:])
  let arr = l.to_array()
  assert_eq(arr.length(), 3)
  assert_eq(arr[0], SExp::int(1))
  assert_eq(arr[2], SExp::int(3))
}

///|
test "structural_equality_handles_each_variant" {
  assert_true(SExp::equal(SExp::int(1), SExp::int(1)))
  assert_false(SExp::equal(SExp::int(1), SExp::int(2)))
  assert_true(SExp::equal(SExp::str("x"), SExp::str("x")))
  assert_true(SExp::equal(SExp::sym("foo"), SExp::sym("foo")))
  assert_false(SExp::equal(SExp::sym("foo"), SExp::str("foo")))
  assert_true(SExp::equal(SExp::nil(), SExp::nil()))
  assert_false(SExp::equal(SExp::nil(), SExp::int(0)))
  let a = SExp::from_array([SExp::int(1), SExp::int(2)][:])
  let b = SExp::from_array([SExp::int(1), SExp::int(2)][:])
  let c = SExp::from_array([SExp::int(1), SExp::int(3)][:])
  assert_true(SExp::equal(a, b))
  assert_false(SExp::equal(a, c))
}

///|
test "predicates_classify_each_variant" {
  let nil = SExp::nil()
  assert_true(nil.self_is_nil())
  assert_false(SExp::int(0).self_is_nil())
  assert_true(SExp::bool_true().self_is_bool())
  assert_false(nil.self_is_bool())
  assert_true(SExp::int(0).self_is_number())
  assert_false(nil.self_is_number())
  assert_true(SExp::str("").self_is_string())
  assert_false(nil.self_is_string())
  assert_true(SExp::sym("x").self_is_symbol())
  assert_false(nil.self_is_symbol())
  let p = SExp::cons(SExp::int(1), SExp::nil())
  assert_true(p.self_is_pair())
  assert_false(nil.self_is_pair())
  assert_true(p.self_is_list())
  assert_false(SExp::cons(SExp::int(1), SExp::int(2)).self_is_list())
}
