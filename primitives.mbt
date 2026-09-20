// primitives.mbt
//
// The primitive library: every built-in function the interpreter
// understands. Each primitive is a thin MoonBit function that takes
// a list of evaluated arguments and returns a value or raises
// `EvalError` / `ArityError`.
//
// A primitive is registered as a marker symbol of the form
// `__primitive__:name`; the `apply` function in `eval.mbt` matches
// on that marker and dispatches to the matching MoonBit
// implementation. This is the same trick Sussman's SICP metacircular
// evaluator uses to mix primitive and defined procedures.

///|
/// Marker value used to denote a primitive when stored as an `SExp`.
/// We piggy-back on `Sym` so the type system does not have to learn
/// about closures. The dispatch happens in `apply` (see `eval.mbt`).
pub fn prim_tag(name : String) -> SExp {
  SExp::sym("__primitive__:" + name)
}

///|
/// `true` iff `value` is a primitive marker with the given `name`.
pub fn self_is_prim(value : SExp, name : String) -> Bool {
  SExp::equal(value, prim_tag(name))
}

///|
/// Extract the primitive name from a marker `SExp`. Returns `None`
/// if `value` is not a primitive marker.
pub fn prim_name_of(value : SExp) -> String? {
  match value {
    Sym(s) =>
      if s.has_prefix("__primitive__:") {
        Some(s.substring(start=14, end=s.length()))
      } else {
        None
      }
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Numeric primitives
// ---------------------------------------------------------------------------

///|
/// `(+ n1 n2 ...)` — sum of all arguments. Variadic.
pub fn prim_add(args : Array[SExp]) -> SExp raise {
  let mut total = 0.0
  for a in args {
    match a {
      Num(n) => total = total + n
      _ => raise TypeMismatch("+", "number")
    }
  }
  SExp::num(total)
}

///|
/// `(- n1 n2 ...)` — variadic; with one argument negates it, with
/// several evaluates `n1 - n2 - n3 - ...`.
pub fn prim_sub(args : Array[SExp]) -> SExp raise {
  if args.length() == 0 {
    raise ArityError::WrongArity("-", 1, 0)
  }
  match args[0] {
    Num(n0) => {
      let mut total = n0
      if args.length() == 1 {
        return SExp::num(-total)
      }
      for i in 1..<args.length() {
        match args[i] {
          Num(n) => total = total - n
          _ => raise TypeMismatch("-", "number")
        }
      }
      SExp::num(total)
    }
    _ => raise TypeMismatch("-", "number")
  }
}

///|
/// `(* n1 n2 ...)` — product of all arguments. Variadic.
pub fn prim_mul(args : Array[SExp]) -> SExp raise {
  let mut total = 1.0
  for a in args {
    match a {
      Num(n) => total = total * n
      _ => raise TypeMismatch("*", "number")
    }
  }
  SExp::num(total)
}

///|
/// `(/ n1 n2 ...)` — variadic; with one argument returns its
/// reciprocal, with several evaluates `n1 / n2 / n3 / ...`. Division
/// by zero raises `EvalFailure`.
pub fn prim_div(args : Array[SExp]) -> SExp raise {
  if args.length() == 0 {
    raise ArityError::WrongArity("/", 1, 0)
  }
  match args[0] {
    Num(n0) => {
      if args.length() == 1 {
        return SExp::num(1.0 / n0)
      }
      let mut total = n0
      for i in 1..<args.length() {
        match args[i] {
          Num(n) =>
            if n == 0.0 {
              raise EvalFailure("division by zero")
            } else {
              total = total / n
            }
          _ => raise TypeMismatch("/", "number")
        }
      }
      SExp::num(total)
    }
    _ => raise TypeMismatch("/", "number")
  }
}

// ---------------------------------------------------------------------------
// Comparison primitives
// ---------------------------------------------------------------------------

///|
/// `(= n1 n2 ...)` — every pair of adjacent arguments is numerically
/// equal.
pub fn prim_eq(args : Array[SExp]) -> SExp raise {
  if args.length() < 2 {
    raise ArityError::WrongArity("=", 2, args.length())
  }
  for i in 1..<args.length() {
    match (args[i - 1], args[i]) {
      (Num(a), Num(b)) => if a != b { return SExp::bool_false() }
      _ => raise TypeMismatch("=", "number")
    }
  }
  SExp::bool_true()
}

///|
/// `(< n1 n2 ...)` — strictly increasing chain.
pub fn prim_lt(args : Array[SExp]) -> SExp raise {
  if args.length() < 2 {
    raise ArityError::WrongArity("<", 2, args.length())
  }
  for i in 1..<args.length() {
    match (args[i - 1], args[i]) {
      (Num(a), Num(b)) => if a >= b { return SExp::bool_false() }
      _ => raise TypeMismatch("<", "number")
    }
  }
  SExp::bool_true()
}

///|
/// `(> n1 n2 ...)` — strictly decreasing chain.
pub fn prim_gt(args : Array[SExp]) -> SExp raise {
  if args.length() < 2 {
    raise ArityError::WrongArity(">", 2, args.length())
  }
  for i in 1..<args.length() {
    match (args[i - 1], args[i]) {
      (Num(a), Num(b)) => if a <= b { return SExp::bool_false() }
      _ => raise TypeMismatch(">", "number")
    }
  }
  SExp::bool_true()
}

///|
/// `(<= n1 n2 ...)` — non-strictly increasing chain.
pub fn prim_le(args : Array[SExp]) -> SExp raise {
  if args.length() < 2 {
    raise ArityError::WrongArity("<=", 2, args.length())
  }
  for i in 1..<args.length() {
    match (args[i - 1], args[i]) {
      (Num(a), Num(b)) => if a > b { return SExp::bool_false() }
      _ => raise TypeMismatch("<=", "number")
    }
  }
  SExp::bool_true()
}

///|
/// `(>= n1 n2 ...)` — non-strictly decreasing chain.
pub fn prim_ge(args : Array[SExp]) -> SExp raise {
  if args.length() < 2 {
    raise ArityError::WrongArity(">=", 2, args.length())
  }
  for i in 1..<args.length() {
    match (args[i - 1], args[i]) {
      (Num(a), Num(b)) => if a < b { return SExp::bool_false() }
      _ => raise TypeMismatch(">=", "number")
    }
  }
  SExp::bool_true()
}

// ---------------------------------------------------------------------------
// Predicate primitives
// ---------------------------------------------------------------------------

///|
/// `(null? x)` — `#t` iff `x` is the empty list.
pub fn prim_nullp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("null?", 1, args.length())
  }
  match args[0] {
    Nil => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(pair? x)` — `#t` iff `x` is a cons cell.
pub fn prim_pairp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("pair?", 1, args.length())
  }
  match args[0] {
    Cons(_, _) => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(number? x)` — `#t` iff `x` is a numeric literal.
pub fn prim_numberp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("number?", 1, args.length())
  }
  match args[0] {
    Num(_) => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(symbol? x)` — `#t` iff `x` is a symbol.
pub fn prim_symbolp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("symbol?", 1, args.length())
  }
  match args[0] {
    Sym(_) => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(string? x)` — `#t` iff `x` is a string literal.
pub fn prim_stringp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("string?", 1, args.length())
  }
  match args[0] {
    Str(_) => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(boolean? x)` — `#t` iff `x` is `#t` or `#f`.
pub fn prim_booleanp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("boolean?", 1, args.length())
  }
  match args[0] {
    Bool(_) => SExp::bool_true()
    _ => SExp::bool_false()
  }
}

///|
/// `(eq? a b)` — `#t` iff `a` and `b` are structurally equal.
pub fn prim_eqp(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 2 {
    raise ArityError::WrongArity("eq?", 2, args.length())
  }
  if SExp::equal(args[0], args[1]) {
    SExp::bool_true()
  } else {
    SExp::bool_false()
  }
}

// ---------------------------------------------------------------------------
// List primitives
// ---------------------------------------------------------------------------

///|
/// `(cons a b)` — build a cons cell.
pub fn prim_cons(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 2 {
    raise ArityError::WrongArity("cons", 2, args.length())
  }
  SExp::cons(args[0], args[1])
}

///|
/// `(car p)` — head of a cons cell.
pub fn prim_car(args : Array[SExp]) -> SExp raise {
  if args.length() != 1 {
    raise ArityError::WrongArity("car", 1, args.length())
  }
  match args[0] {
    Cons(car, _) => car
    _ => raise TypeMismatch("car", "pair")
  }
}

///|
/// `(cdr p)` — tail of a cons cell.
pub fn prim_cdr(args : Array[SExp]) -> SExp raise {
  if args.length() != 1 {
    raise ArityError::WrongArity("cdr", 1, args.length())
  }
  match args[0] {
    Cons(_, cdr) => cdr
    _ => raise TypeMismatch("cdr", "pair")
  }
}

///|
/// `(list a b ...)` — build a proper list from the arguments.
pub fn prim_list(args : Array[SExp]) -> SExp {
  SExp::from_array(args)
}

///|
/// `(length lst)` — number of cons cells in a proper list. Non-list
/// arguments raise `TypeMismatch`.
pub fn prim_length(args : Array[SExp]) -> SExp raise {
  if args.length() != 1 {
    raise ArityError::WrongArity("length", 1, args.length())
  }
  match args[0] {
    Nil => SExp::int(0)
    Cons(_, _) =>
      match args[0].self_is_list() {
        true => SExp::int(args[0].to_array().length())
        false => raise TypeMismatch("length", "list")
      }
    _ => raise TypeMismatch("length", "list")
  }
}

///|
/// `(append a b)` — concatenate two lists.
pub fn prim_append(args : Array[SExp]) -> SExp raise {
  if args.length() != 2 {
    raise ArityError::WrongArity("append", 2, args.length())
  }
  match (args[0], args[1]) {
    (Nil, other) => other
    (Cons(_, _), other) => {
      if not(args[0].self_is_list()) {
        raise TypeMismatch("append", "list")
      }
      let items = args[0].to_array()
      let mut out = other
      for i = items.length() - 1; i >= 0; i = i - 1 {
        out = SExp::cons(items[i], out)
      }
      out
    }
    _ => raise TypeMismatch("append", "list")
  }
}

///|
/// `(reverse lst)` — return a list with elements in reverse order.
pub fn prim_reverse(args : Array[SExp]) -> SExp raise {
  if args.length() != 1 {
    raise ArityError::WrongArity("reverse", 1, args.length())
  }
  match args[0] {
    Nil => Nil
    Cons(_, _) =>
      if not(args[0].self_is_list()) {
        raise TypeMismatch("reverse", "list")
      } else {
        let items = args[0].to_array()
        let mut out : SExp = Nil
        for i = 0; i < items.length(); i = i + 1 {
          out = SExp::cons(items[i], out)
        }
        out
      }
    _ => raise TypeMismatch("reverse", "list")
  }
}

// ---------------------------------------------------------------------------
// I/O and conversion primitives
// ---------------------------------------------------------------------------

///|
/// `(display x)` — print `x` without surrounding quotes; returns the
/// empty list. Used by the bundled example programs.
pub fn prim_display(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("display", 1, args.length())
  }
  let s = match args[0] {
    Str(t) => t
    other => other.to_string()
  }
  println(s)
  SExp::nil()
}

///|
/// `(print x)` — print `x` and a trailing newline; returns the empty
/// list.
pub fn prim_print(args : Array[SExp]) -> SExp raise ArityError {
  if args.length() != 1 {
    raise ArityError::WrongArity("print", 1, args.length())
  }
  let s = match args[0] {
    Str(t) => t
    other => other.to_string()
  }
  println(s)
  SExp::nil()
}

///|
/// `(number->string n)` — convert a number to its decimal string
/// representation.
pub fn prim_number_to_string(args : Array[SExp]) -> SExp raise {
  if args.length() != 1 {
    raise ArityError::WrongArity("number->string", 1, args.length())
  }
  match args[0] {
    Num(n) =>
      if n == n.trunc() && n.abs() < 1.0e16 {
        SExp::str(n.to_int64().to_string())
      } else {
        SExp::str(n.to_string())
      }
    _ => raise TypeMismatch("number->string", "number")
  }
}
