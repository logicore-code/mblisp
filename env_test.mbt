// env_test.mbt
//
// Black-box tests for the lexical environment.

///|
test "new_env_is_global" {
  let g = Env::new()
  assert_true(g.self_is_global())
}

///|
test "bind_then_lookup" {
  let g = Env::new() |> Env::bind("x", SExp::int(42))
  assert_eq(g.lookup("x"), Some(SExp::int(42)))
}

///|
test "child_shadows_parent_binding" {
  let g = Env::new() |> Env::bind("x", SExp::int(1))
  let child = g |> Env::child() |> Env::bind("x", SExp::int(2))
  assert_eq(child.lookup("x"), Some(SExp::int(2)))
  // Outer binding is untouched.
  assert_eq(g.lookup("x"), Some(SExp::int(1)))
}

///|
test "child_falls_through_to_parent" {
  let g = Env::new() |> Env::bind("x", SExp::int(10))
  let child = g |> Env::child() |> Env::bind("y", SExp::int(20))
  assert_eq(child.lookup("x"), Some(SExp::int(10)))
  assert_eq(child.lookup("y"), Some(SExp::int(20)))
}

///|
test "lookup_unbound_returns_none" {
  let g = Env::new()
  assert_eq(g.lookup("nope"), None)
}

///|
test "assign_updates_first_frame_that_defines_it" {
  let g = Env::new() |> Env::bind("x", SExp::int(1))
  let child = g |> Env::child() |> Env::bind("y", SExp::int(2))
  let child2 = child.assign("x", SExp::int(99))
  // Child still sees the new value via fallback to parent.
  assert_eq(child2.lookup("x"), Some(SExp::int(99)))
  // Original parent chain is *not* mutated.
  assert_eq(g.lookup("x"), Some(SExp::int(1)))
  // child is not mutated either.
  assert_eq(child.lookup("x"), Some(SExp::int(1)))
}

///|
test "assign_on_unbound_is_noop" {
  let g = Env::new()
  let g2 = g.assign("missing", SExp::int(1))
  assert_eq(g2.lookup("missing"), None)
}

///|
test "local_size_counts_only_current_frame" {
  let g = Env::new() |> Env::bind("a", SExp::int(1))
  let child = g |> Env::child() |> Env::bind("b", SExp::int(2))
  assert_eq(g.local_size(), 1)
  assert_eq(child.local_size(), 1)
}

///|
test "total_size_walks_parent_chain" {
  let g = Env::new()
    |> Env::bind("a", SExp::int(1))
    |> Env::bind("b", SExp::int(2))
  let child = g |> Env::child() |> Env::bind("c", SExp::int(3))
  assert_eq(g.total_size(), 2)
  assert_eq(child.total_size(), 3)
}
