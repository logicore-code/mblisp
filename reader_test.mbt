// reader_test.mbt
//
// Black-box tests for the S-expression reader.

///|
test "read_atom_number" {
  let e = read_one("42")
  assert_eq(e, SExp::int(42))
}

///|
test "read_atom_negative_number" {
  let e = read_one("-7")
  assert_eq(e, SExp::int(-7))
}

///|
test "read_atom_float" {
  let e = read_one("3.14")
  assert_eq(e, SExp::num(3.14))
}

///|
test "read_atom_symbol" {
  let e = read_one("foo-bar!")
  assert_eq(e, SExp::sym("foo-bar!"))
}

///|
test "read_atom_string" {
  let e = read_one("\"hello, world\"")
  assert_eq(e, SExp::str("hello, world"))
}

///|
test "read_string_with_escape_sequences" {
  let e = read_one("\"line1\\nline2\\t\\\"end\\\"\"")
  assert_eq(e, SExp::str("line1\nline2\t\"end\""))
}

///|
test "read_atom_bool_true" {
  assert_eq(read_one("#t"), SExp::bool_true())
}

///|
test "read_atom_bool_false" {
  assert_eq(read_one("#f"), SExp::bool_false())
}

///|
test "read_nil" {
  assert_eq(read_one("()"), SExp::nil())
}

///|
test "read_proper_list" {
  let e = read_one("(1 2 3)")
  assert_eq(e, SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:]))
}

///|
test "read_nested_list" {
  let e = read_one("(a (b c) d)")
  assert_eq(
    e,
    SExp::from_array([
      SExp::sym("a"),
      SExp::from_array([SExp::sym("b"), SExp::sym("c")][:]),
      SExp::sym("d"),
    ]),
  )
}

///|
test "read_dotted_pair" {
  let e = read_one("(1 . 2)")
  assert_eq(e, SExp::cons(SExp::int(1), SExp::int(2)))
}

///|
test "read_dotted_list" {
  let e = read_one("(1 2 . 3)")
  assert_eq(e, SExp::cons(SExp::int(1), SExp::cons(SExp::int(2), SExp::int(3))))
}

///|
test "read_quoted_form" {
  let e = read_one("'foo")
  assert_eq(
    e,
    SExp::cons(SExp::sym("quote"), SExp::cons(SExp::sym("foo"), SExp::nil())),
  )
}

///|
test "read_quoted_list" {
  let e = read_one("'(1 2)")
  assert_eq(
    e,
    SExp::cons(
      SExp::sym("quote"),
      SExp::cons(SExp::from_array([SExp::int(1), SExp::int(2)][:]), SExp::nil()),
    ),
  )
}

///|
test "read_skip_whitespace_and_comments" {
  let src = "  ; a comment\n  42  ; another\n  "
  let all = read_all(src)
  assert_eq(all.length(), 1)
  assert_eq(all[0], SExp::int(42))
}

///|
test "read_multiple_top_level_expressions" {
  let src = "1 2 (a b) \"x\""
  let all = read_all(src)
  assert_eq(all.length(), 4)
  assert_eq(all[0], SExp::int(1))
  assert_eq(all[1], SExp::int(2))
  assert_eq(all[2], SExp::from_array([SExp::sym("a"), SExp::sym("b")][:]))
  assert_eq(all[3], SExp::str("x"))
}

///|
test "read_unbalanced_paren_raises" {
  let raised : Bool = try {
    read_one("(1 2") |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "read_unexpected_close_paren_raises" {
  let raised : Bool = try {
    read_one(")") |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "read_unterminated_string_raises" {
  let raised : Bool = try {
    read_one("\"oops") |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "round_trip_simple_sexp_through_reader" {
  // Round-tripping through `to_string` is not lossless for every form
  // (notably `-` and `+` are read as numeric signs), but it is lossless
  // for symbol-only and parenthesised-symbol-only forms.
  let src = "(define fact x)"
  let e = read_one(src)
  let round = e.to_string()
  let again = read_one(round)
  assert_true(SExp::equal(e, again))
}
