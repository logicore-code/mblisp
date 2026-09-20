// sexp.mbt
//
// The `SExp` type is the single algebraic datatype at the heart of the
// interpreter. Everything that flows through the reader, the
// environment, the evaluator and the primitive library is an `SExp`,
// which keeps the implementation compact and lets MoonBit's pattern
// matching do most of the heavy lifting.
//
// Variants:
//
//   - `Num(Double)`   : IEEE-754 floating point number (Scheme has a
//                        single numeric tower).
//   - `Str(String)`   : a string literal, immutable.
//   - `Sym(String)`   : a symbol / identifier, interned by the reader.
//   - `Bool(Bool)`    : `#t` and `#f` literals.
//   - `Nil`           : the empty list, also written `()`.
//   - `Cons(SExp, SExp)` : a pair; recursive lists are nested `Cons`.
//
// Pairs are constructed eagerly. Lists are detected by the
// `SExp::list?` predicate and the `SExp::as_list_view` helper.

///|
/// The runtime value of every Lisp expression.
pub enum SExp {
  /// A numeric literal. We use `Double` rather than `Int` to keep the
  /// numeric tower uniform with Scheme's specification.
  Num(Double)
  /// A string literal.
  Str(String)
  /// A symbol / identifier.
  Sym(String)
  /// A boolean literal: `#t` or `#f`.
  Bool(Bool)
  /// The empty list, written `()`.
  Nil
  /// A cons cell `(a . b)`. Lists are nested cons cells ending in
  /// `Nil`.
  Cons(SExp, SExp)
} derive(Debug, Eq)

///|
/// `true` iff `self` is a proper list (a nested `Cons` ending in `Nil`).
pub fn SExp::self_is_list(self : SExp) -> Bool {
  match self {
    Nil => true
    Cons(_, rest) => rest.self_is_list()
    _ => false
  }
}

///|
/// `true` iff `self` is the empty list / nil.
pub fn SExp::self_is_nil(self : SExp) -> Bool {
  match self {
    Nil => true
    _ => false
  }
}

///|
/// `true` iff `self` is a boolean literal.
pub fn SExp::self_is_bool(self : SExp) -> Bool {
  match self {
    Bool(_) => true
    _ => false
  }
}

///|
/// `true` iff `self` is a number literal.
pub fn SExp::self_is_number(self : SExp) -> Bool {
  match self {
    Num(_) => true
    _ => false
  }
}

///|
/// `true` iff `self` is a string literal.
pub fn SExp::self_is_string(self : SExp) -> Bool {
  match self {
    Str(_) => true
    _ => false
  }
}

///|
/// `true` iff `self` is a symbol.
pub fn SExp::self_is_symbol(self : SExp) -> Bool {
  match self {
    Sym(_) => true
    _ => false
  }
}

///|
/// `true` iff `self` is a cons cell.
pub fn SExp::self_is_pair(self : SExp) -> Bool {
  match self {
    Cons(_, _) => true
    _ => false
  }
}

///|
/// Structural equality on `SExp` values. Two numbers compare by value
/// even though they live behind `Double`; strings and symbols by
/// content; pairs recursively; everything else by construction.
pub fn SExp::equal(a : SExp, b : SExp) -> Bool {
  match (a, b) {
    (Num(x), Num(y)) => x == y
    (Str(x), Str(y)) => x == y
    (Sym(x), Sym(y)) => x == y
    (Bool(x), Bool(y)) => x == y
    (Nil, Nil) => true
    (Cons(ax, ad), Cons(bx, bd)) => SExp::equal(ax, bx) && SExp::equal(ad, bd)
    _ => false
  }
}

///|
/// Pretty-printer that round-trips through the reader: numbers print
/// without trailing decimals, lists print with `(` ... `)`, pairs print
/// as `(a . b)`, strings are quoted and escaped.
pub fn SExp::to_string(self : SExp) -> String {
  let buf = StringBuilder()
  self.write_to(buf)
  buf.to_string()
}

///|
/// Internal: stream-append a representation of `self` to `buf`.
fn SExp::write_to(self : SExp, buf : StringBuilder) -> Unit {
  match self {
    Num(n) =>
      // Print integers without a trailing `.0` so the round-trip
      // through `read` produces the same numeric literal.
      if n == n.trunc() && n.abs() < 1.0e16 {
        buf.write_string(n.to_int64().to_string())
      } else {
        buf.write_string(n.to_string())
      }
    Str(s) => {
      buf.write_char('"')
      for ch in s {
        if ch == '"' || ch == '\\' {
          buf.write_char('\\')
        }
        buf.write_char(ch)
      }
      buf.write_char('"')
    }
    Sym(name) => buf.write_string(name)
    Bool(true) => buf.write_string("#t")
    Bool(false) => buf.write_string("#f")
    Nil => buf.write_string("()")
    Cons(_, _) => write_list_to(self, buf)
  }
}

///|
/// Internal: write a `Cons` spine to `buf`, choosing between list,
/// dotted pair and improper-list formatting depending on the tail.
fn write_list_to(s : SExp, buf : StringBuilder) -> Unit {
  buf.write_char('(')
  let mut cur = s
  let mut first = true
  while true {
    match cur {
      Nil => break
      Cons(car, cdr) => {
        if !first {
          buf.write_char(' ')
        }
        first = false
        match write_car(car, buf) {
          _ => ()
        }
        match cdr {
          Nil => break
          Cons(_, _) => cur = cdr
          tail => {
            buf.write_string(" . ")
            tail.write_to(buf)
            break
          }
        }
      }
      _ =>
        // Should be unreachable: write_list_to is only called from
        // the `Cons(_, _)` arm of `write_to`.
        break
    }
  }
  buf.write_char(')')
}

///|
/// Internal: write a single element. Kept as a small helper so the
/// loop above stays readable.
fn write_car(s : SExp, buf : StringBuilder) -> Unit {
  s.write_to(buf)
}

///|
/// Convert a (possibly improper) `SExp` list into a plain array. If
/// the input is not a proper list, the tail atom is appended at the
/// end so callers can still pattern-match on `Option::None` for the
/// end-of-list marker.
pub fn SExp::to_array(self : SExp) -> Array[SExp] {
  let out : Array[SExp] = []
  let mut cur = self
  while true {
    match cur {
      Nil => break
      Cons(car, cdr) => {
        out.push(car)
        cur = cdr
      }
      other => {
        // Improper list: keep the tail atom as the last element.
        out.push(other)
        break
      }
    }
  }
  out
}

///|
/// Build a proper list from an array of elements. The empty array
/// yields `Nil`.
pub fn SExp::from_array(items : ArrayView[SExp]) -> SExp {
  let mut out : SExp = Nil
  for i = items.length() - 1; i >= 0; i = i - 1 {
    out = Cons(items[i], out)
  }
  out
}

///|
/// Convenience constructor for a pair (dotted pair `(a . b)`).
pub fn SExp::cons(a : SExp, b : SExp) -> SExp {
  Cons(a, b)
}

///|
/// Convenience constructor for a numeric literal from a MoonBit `Int`.
pub fn SExp::int(n : Int) -> SExp {
  Num(n.to_double())
}

///|
/// Convenience constructor for a numeric literal from a MoonBit `Double`.
pub fn SExp::num(n : Double) -> SExp {
  Num(n)
}

///|
/// Convenience constructor for a string literal.
pub fn SExp::str(s : String) -> SExp {
  Str(s)
}

///|
/// Convenience constructor for a symbol.
pub fn SExp::sym(name : String) -> SExp {
  Sym(name)
}

///|
/// Convenience constructor for a boolean literal.
pub fn SExp::bool_true() -> SExp {
  Bool(true)
}

///|
/// Convenience constructor for the false boolean literal.
pub fn SExp::bool_false() -> SExp {
  Bool(false)
}

///|
/// Convenience constructor for the empty list (`Nil`).
pub fn SExp::nil() -> SExp {
  Nil
}
