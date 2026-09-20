// primitives_test.mbt
//
// Black-box tests for the primitive library. The tests are written as
// direct calls to the primitive functions (not through the evaluator)
// so they pin down the numerical, structural and error behaviour of
// each primitive in isolation.

///|
test "prim_add_sums_variadic_arguments" {
  let r = prim_add([SExp::int(1), SExp::int(2), SExp::int(3), SExp::int(4)])
  assert_eq(r, SExp::int(10))
}

///|
test "prim_sub_with_one_argument_negates" {
  let r = prim_sub([SExp::int(5)])
  assert_eq(r, SExp::int(-5))
}

///|
test "prim_sub_chains_left_to_right" {
  let r = prim_sub([SExp::int(10), SExp::int(3), SExp::int(2)])
  assert_eq(r, SExp::int(5))
}

///|
test "prim_mul_multiplies_variadic_arguments" {
  let r = prim_mul([SExp::int(2), SExp::int(3), SExp::int(4)])
  assert_eq(r, SExp::int(24))
}

///|
test "prim_div_chains_left_to_right" {
  let r = prim_div([SExp::int(20), SExp::int(4), SExp::int(5)])
  assert_eq(r, SExp::int(1))
}

///|
test "prim_eq_returns_true_when_all_pairs_match" {
  assert_eq(
    prim_eq([SExp::int(3), SExp::int(3), SExp::int(3)]),
    SExp::bool_true(),
  )
}

///|
test "prim_eq_returns_false_when_a_pair_differs" {
  assert_eq(prim_eq([SExp::int(3), SExp::int(4)]), SExp::bool_false())
}

///|
test "prim_lt_enforces_strictly_increasing_chain" {
  assert_eq(
    prim_lt([SExp::int(1), SExp::int(2), SExp::int(3)]),
    SExp::bool_true(),
  )
  assert_eq(
    prim_lt([SExp::int(1), SExp::int(2), SExp::int(2)]),
    SExp::bool_false(),
  )
  assert_eq(prim_lt([SExp::int(3), SExp::int(2)]), SExp::bool_false())
}

///|
test "prim_le_allows_equal_neighbours" {
  assert_eq(
    prim_le([SExp::int(1), SExp::int(2), SExp::int(2), SExp::int(3)]),
    SExp::bool_true(),
  )
}

///|
test "prim_gt_enforces_strictly_decreasing_chain" {
  assert_eq(
    prim_gt([SExp::int(3), SExp::int(2), SExp::int(1)]),
    SExp::bool_true(),
  )
  assert_eq(prim_gt([SExp::int(3), SExp::int(3)]), SExp::bool_false())
}

///|
test "prim_nullp" {
  assert_eq(prim_nullp([SExp::nil()]), SExp::bool_true())
  assert_eq(prim_nullp([SExp::int(1)]), SExp::bool_false())
  assert_eq(
    prim_nullp([SExp::from_array([SExp::int(1)][:])]),
    SExp::bool_false(),
  )
}

///|
test "prim_pairp" {
  let p = SExp::cons(SExp::int(1), SExp::int(2))
  assert_eq(prim_pairp([p]), SExp::bool_true())
  assert_eq(prim_pairp([SExp::nil()]), SExp::bool_false())
}

///|
test "prim_numberp_symbolp_stringp_booleanp" {
  assert_eq(prim_numberp([SExp::int(1)]), SExp::bool_true())
  assert_eq(prim_numberp([SExp::sym("x")]), SExp::bool_false())
  assert_eq(prim_symbolp([SExp::sym("x")]), SExp::bool_true())
  assert_eq(prim_stringp([SExp::str("x")]), SExp::bool_true())
  assert_eq(prim_booleanp([SExp::bool_true()]), SExp::bool_true())
}

///|
test "prim_eqp_uses_structural_equality" {
  let a = SExp::from_array([SExp::int(1), SExp::int(2)][:])
  let b = SExp::from_array([SExp::int(1), SExp::int(2)][:])
  let c = SExp::from_array([SExp::int(1), SExp::int(3)][:])
  assert_eq(prim_eqp([a, b]), SExp::bool_true())
  assert_eq(prim_eqp([a, c]), SExp::bool_false())
}

///|
test "prim_cons_car_cdr_round_trip" {
  let p = prim_cons([SExp::int(1), SExp::int(2)])
  assert_eq(prim_car([p]), SExp::int(1))
  assert_eq(prim_cdr([p]), SExp::int(2))
}

///|
test "prim_list_builds_a_proper_list" {
  let r = prim_list([SExp::int(1), SExp::int(2), SExp::int(3)])
  assert_eq(r, SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:]))
}

///|
test "prim_length_returns_element_count" {
  let r = prim_length([
    SExp::from_array(
      [SExp::int(1), SExp::int(2), SExp::int(3), SExp::int(4)][:],
    ),
  ])
  assert_eq(r, SExp::int(4))
  assert_eq(prim_length([SExp::nil()]), SExp::int(0))
}

///|
test "prim_append_concatenates_lists" {
  let a = SExp::from_array([SExp::int(1), SExp::int(2)][:])
  let b = SExp::from_array([SExp::int(3), SExp::int(4)][:])
  let r = prim_append([a, b])
  assert_eq(
    r,
    SExp::from_array(
      [SExp::int(1), SExp::int(2), SExp::int(3), SExp::int(4)][:],
    ),
  )
}

///|
test "prim_reverse_returns_a_reversed_list" {
  let a = SExp::from_array([SExp::int(1), SExp::int(2), SExp::int(3)][:])
  let r = prim_reverse([a])
  assert_eq(r, SExp::from_array([SExp::int(3), SExp::int(2), SExp::int(1)][:]))
}

///|
test "prim_car_raises_type_mismatch_on_non_pair" {
  let raised : Bool = try {
    prim_car([SExp::int(1)]) |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}

///|
test "prim_length_raises_on_arity_mismatch" {
  let raised : Bool = try {
    prim_length([SExp::int(1), SExp::int(2)]) |> ignore
    false
  } catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(raised)
}
