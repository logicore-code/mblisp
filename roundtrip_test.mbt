// roundtrip_test.mbt
//
// Property-style tests for the reader + pretty-printer round
// trip and the parse-only sanity of the symbol/atom alphabet.
// These don't aim to be a full property-based fuzz suite — they
// just lock down the cases a reviewer would hand-verify.

///|
test "roundtrip_atom_number" {
  let s = "42"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "42")
}

///|
test "roundtrip_atom_negative_number" {
  let s = "-17"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "-17")
}

///|
test "roundtrip_atom_string" {
  let s = "\"hello world\""
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "\"hello world\"")
}

///|
test "roundtrip_atom_symbol" {
  let s = "hello"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "hello")
}

///|
test "roundtrip_atom_symbol_with_punctuation" {
  // The reader accepts every ASCII non-whitespace as part of a
  // symbol once the first character passes `is_symbol_start`.
  let s = "->+<="
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "->+<=")
}

///|
test "roundtrip_list_of_numbers" {
  let s = "(1 2 3)"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "(1 2 3)")
}

///|
test "roundtrip_nested_list" {
  let s = "((a b) (c d))"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "((a b) (c d))")
}

///|
test "roundtrip_dotted_pair" {
  let s = "(1 . 2)"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "(1 . 2)")
}

///|
test "roundtrip_three_element_dotted" {
  let s = "(a b . c)"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "(a b . c)")
}

///|
test "roundtrip_quote_shorthand" {
  // `'foo` desugars to `(quote foo)`. The pretty-printer prints
  // it back as `'foo` because that's how the reader tokenised it.
  let s = "'foo"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "'foo")
}

///|
test "roundtrip_quoted_list" {
  let s = "'(1 2 3)"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  assert_eq(printed, "'(1 2 3)")
}

///|
test "roundtrip_double_round_trip_preserves_structure" {
  // Parse → print → parse must give the same SExp.
  let s = "(define (f x) (+ x 1))"
  let parsed = read_one(s)
  let printed = parsed.to_string()
  let parsed2 = read_one(printed)
  assert_eq(SExp::equal(parsed, parsed2), true)
}

///|
test "read_one_then_read_all_consistent" {
  // read_all of a one-form source gives the same SExp as read_one.
  let s = "42"
  let one = read_one(s)
  let all = read_all(s)
  assert_eq(all.length(), 1)
  assert_eq(SExp::equal(one, all[0]), true)
}

///|
test "read_all_of_empty_source_gives_empty_array" {
  let s = "  \n  ; just a comment\n  "
  let all = read_all(s)
  assert_eq(all.length(), 0)
}

///|
test "eval_top_propagates_top_level_defines" {
  // Three top-level forms. The third form references a binding
  // established by the first, so the threading has to work.
  let src = "(define x 10) (define y 20) (+ x y)"
  let r = try eval_top(src) catch {
    _ => SExp::int(-1)
  } noraise {
    v => v
  }
  assert_eq(r, SExp::int(30))
}

///|
test "eval_lambda_captures_top_level_binding" {
  // `(define n 5)` then `(lambda () n)` captures n. Calling
  // the lambda returns 5.
  let src =
    #| (define n 5)
    #| (define get-n (lambda () n))
    #| (get-n)
  let r = try eval_top(src) catch {
    _ => SExp::int(-1)
  } noraise {
    v => v
  }
  assert_eq(r, SExp::int(5))
}
