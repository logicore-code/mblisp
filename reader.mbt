// reader.mbt
//
// The reader turns a chunk of source text into a stream of balanced
// s-expressions. It is hand-written rather than table-driven so the
// interpreter stays small and easy to read.
//
// Lexical grammar (informal):
//
//   comment      := ; until end of line
//   whitespace   := ' ' | '\t' | '\n' | '\r'
//   number       := [-]digit+ [. digit+]
//   string       := " (\" | \\ | any-non-" )* "
//   symbol       := letter (letter | digit | - | + | ! | ? | . | / | * | < | > | = | :)*
//   bool         := #t | #f
//   list         := ( s-expr* )
//   dotted       := ( s-expr+ . s-expr )
//   quote        := ' s-expr
//
// A script may contain any number of top-level s-expressions; the reader
// returns them as an array. Whitespace and comments between expressions
// are skipped.

///|
/// Read every top-level s-expression in `input` and return them as an
/// array. `ReadError` is raised on unbalanced parentheses or invalid
/// literals.
pub fn read_all(input : String) -> Array[SExp] raise ReadError {
  let r : Reader = { src: input, pos: 0, }
  let out : Array[SExp] = []
  while not(r.at_end()) {
    skip_trivia(r)
    if r.at_end() {
      break
    }
    out.push(read_expr(r))
  }
  out
}

///|
/// Read a single s-expression. Useful when the caller knows that the
/// input contains exactly one expression.
pub fn read_one(input : String) -> SExp raise ReadError {
  let r : Reader = { src: input, pos: 0, }
  skip_trivia(r)
  let e = read_expr(r)
  skip_trivia(r)
  if not(r.at_end()) {
    raise UnmatchedParen(r.pos)
  }
  e
}

///|
/// Internal cursor over the source text.
struct Reader {
  src : String
  mut pos : Int
}

///|
/// `true` iff the cursor is past the last byte.
fn Reader::at_end(self : Reader) -> Bool {
  self.pos >= self.src.length()
}

///|
/// Peek at the byte at the cursor without advancing. Returns
/// `'\u0000'` at end-of-input to keep the call sites branchless.
fn Reader::peek(self : Reader) -> Char {
  if self.at_end() {
    '\u0000'
  } else {
    self.src[self.pos].to_int().unsafe_to_char()
  }
}

///|
/// Consume the next byte and return it. Returns `'\u0000'` at end.
fn Reader::next(self : Reader) -> Char {
  let ch = self.peek()
  if not(self.at_end()) {
    self.pos = self.pos + 1
  }
  ch
}

///|
/// Skip whitespace and `;` comments.
fn skip_trivia(r : Reader) -> Unit {
  while not(r.at_end()) {
    match r.peek() {
      ' ' | '\t' | '\n' | '\r' => r.next() |> ignore
      ';' =>
        while not(r.at_end()) {
          let ch = r.next()
          if ch == '\n' {
            break
          }
        }
      _ => break
    }
  }
}

///|
/// Read one s-expression starting at the cursor.
fn read_expr(r : Reader) -> SExp raise ReadError {
  let ch = r.peek()
  match ch {
    '(' => read_list(r)
    '\'' => {
      r.next() |> ignore
      SExp::cons(SExp::sym("quote"), SExp::cons(read_expr(r), SExp::nil()))
    }
    '"' => read_string(r)
    '#' => read_bool(r)
    '-' =>
      // `-` is the leading sign of a numeric literal only when the
      // *immediately following* character is a digit; otherwise it is
      // a bare symbol (`-`, `-foo`, `number->string`, …).
      if has_digit_after(r) {
        read_number(r)
      } else {
        read_symbol(r)
      }
    '+' => read_symbol(r)
    '0'..='9' => read_number(r)
    _ if is_symbol_start(ch) => read_symbol(r)
    _ => raise InvalidChar(r.pos, ch)
  }
}

///|
/// Peek whether the byte immediately after the cursor is an ASCII
/// digit. Used to disambiguate the `-` (or `+`) prefix on a number
/// from a symbol like `-` or `number->string`.
fn has_digit_after(r : Reader) -> Bool {
  if r.pos + 1 >= r.src.length() {
    false
  } else {
    let next = r.src.unsafe_char_at(r.pos + 1)
    next >= '0' && next <= '9'
  }
}

///|
/// `true` iff `ch` can appear as the first character of a symbol.
fn is_symbol_start(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  ch == '!' ||
  ch == '$' ||
  ch == '&' ||
  ch == '*' ||
  ch == '+' ||
  ch == '-' ||
  ch == '/' ||
  ch == ':' ||
  ch == '<' ||
  ch == '=' ||
  ch == '>' ||
  ch == '?' ||
  ch == '~' ||
  ch == '_' ||
  ch == '^'
}

///|
/// `true` iff `ch` can appear in the body of a symbol.
fn is_symbol_cont(ch : Char) -> Bool {
  is_symbol_start(ch) ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '+' ||
  ch == '.' ||
  ch == '@' ||
  ch == '#'
}

///|
/// Read a parenthesised list, optionally dotted.
fn read_list(r : Reader) -> SExp raise ReadError {
  let open = r.next()
  if open != '(' {
    raise InvalidChar(r.pos, open)
  }
  let items : Array[SExp] = []
  let mut dotted_tail : SExp? = None
  skip_trivia(r)
  if r.peek() == ')' {
    r.next() |> ignore
    return SExp::nil()
  }
  while true {
    skip_trivia(r)
    let next_ch = r.peek()
    if next_ch == ')' {
      r.next() |> ignore
      break
    }
    if next_ch == '.' && is_dot_at_top(r) {
      // `.` only introduces a tail when followed by whitespace or a
      // closing paren; otherwise it is part of a number/symbol.
      r.next() |> ignore
      skip_trivia(r)
      dotted_tail = Some(read_expr(r))
      skip_trivia(r)
      if r.peek() != ')' {
        raise UnmatchedParen(r.pos)
      }
      r.next() |> ignore
      break
    }
    items.push(read_expr(r))
  }
  match dotted_tail {
    Some(tail) => array_to_improper(items, tail)
    None => SExp::from_array(items)
  }
}

///|
/// Helper: build `(item0 item1 ... . tail)` from an array plus a tail.
fn array_to_improper(items : Array[SExp], tail : SExp) -> SExp {
  let mut out = tail
  for i = items.length() - 1; i >= 0; i = i - 1 {
    out = SExp::cons(items[i], out)
  }
  out
}

///|
/// Peek whether the dot is at a position that would start a tail
/// rather than appear inside a number. Returns `true` when the
/// previous character was whitespace, the opening paren, or another
/// list-opening character.
fn is_dot_at_top(r : Reader) -> Bool {
  // The previous non-trivia character must be `(`, `[`, or start of
  // input. For simplicity we treat a dot as a tail marker when the
  // next character is whitespace or `)`.
  let after = if r.pos + 1 < r.src.length() {
    r.src[r.pos + 1]
  } else {
    '\u0000'
  }
  after == ' ' ||
  after == '\t' ||
  after == '\n' ||
  after == '\r' ||
  after == ')' ||
  after == '(' ||
  after == '\u0000'
}

///|
/// Read a string literal. Handles `\"` and `\\` escape sequences.
fn read_string(r : Reader) -> SExp raise ReadError {
  let open = r.next()
  if open != '"' {
    raise InvalidChar(r.pos, open)
  }
  let buf = StringBuilder()
  while not(r.at_end()) {
    let ch = r.next()
    if ch == '"' {
      return SExp::str(buf.to_string())
    }
    if ch == '\\' {
      let esc = r.next()
      match esc {
        'n' => buf.write_char('\n')
        't' => buf.write_char('\t')
        'r' => buf.write_char('\r')
        '"' => buf.write_char('"')
        '\\' => buf.write_char('\\')
        _ => buf.write_char(esc)
      }
    } else {
      buf.write_char(ch)
    }
  }
  raise UnexpectedEOF("string literal")
}

///|
/// Read a boolean literal (`#t` or `#f`).
fn read_bool(r : Reader) -> SExp raise ReadError {
  r.next() |> ignore
  let ch = r.next()
  match ch {
    't' => SExp::bool_true()
    'f' => SExp::bool_false()
    _ => raise InvalidLiteral(r.pos, "#\{ch}")
  }
}

///|
/// Read a numeric literal. Accepts integers and floats; negative
/// numbers are parsed as a unary minus applied to the value.
fn read_number(r : Reader) -> SExp raise ReadError {
  let start = r.pos
  let mut s = ""
  if r.peek() == '-' {
    s = s + r.next().to_string()
  }
  while not(r.at_end()) {
    let ch = r.peek()
    let is_digit = ch >= '0' && ch <= '9'
    let is_dot = ch == '.'
    let is_exp = ch == 'e' || ch == 'E'
    if is_digit || is_dot || is_exp || ch == '-' || ch == '+' {
      s = s + r.next().to_string()
    } else {
      break
    }
  }
  match parse_double(s) {
    Some(n) => SExp::num(n)
    None => raise InvalidLiteral(start, s)
  }
}

///|
/// Parse a numeric literal as a `Double`. Returns `None` on failure.
fn parse_double(s : String) -> Double? {
  // Manual parsing to keep the dependency surface small.
  let bytes = s.to_array()
  if bytes.length() == 0 {
    return None
  }
  let mut neg = false
  let mut idx = 0
  if bytes[0] == '-' {
    neg = true
    idx = 1
  } else if bytes[0] == '+' {
    idx = 1
  }
  let mut int_part : Double = 0.0
  let mut saw_digit = false
  while idx < bytes.length() {
    let c = bytes[idx]
    if c >= '0' && c <= '9' {
      int_part = int_part * 10.0 + (c.to_int() - '0'.to_int()).to_double()
      saw_digit = true
      idx = idx + 1
    } else {
      break
    }
  }
  let mut frac_part : Double = 0.0
  let mut frac_div : Double = 1.0
  if idx < bytes.length() && bytes[idx] == '.' {
    idx = idx + 1
    while idx < bytes.length() {
      let c = bytes[idx]
      if c >= '0' && c <= '9' {
        frac_div = frac_div * 10.0
        frac_part = frac_part * 10.0 + (c.to_int() - '0'.to_int()).to_double()
        saw_digit = true
        idx = idx + 1
      } else {
        break
      }
    }
  }
  let mut exp_part : Int = 0
  let mut exp_neg = false
  let mut saw_exp = false
  if idx < bytes.length() && (bytes[idx] == 'e' || bytes[idx] == 'E') {
    saw_exp = true
    idx = idx + 1
    if idx < bytes.length() && (bytes[idx] == '+' || bytes[idx] == '-') {
      exp_neg = bytes[idx] == '-'
      idx = idx + 1
    }
    while idx < bytes.length() {
      let c = bytes[idx]
      if c >= '0' && c <= '9' {
        exp_part = exp_part * 10 + (c.to_int() - '0'.to_int())
        idx = idx + 1
      } else {
        break
      }
    }
  }
  if !saw_digit || idx < bytes.length() {
    None
  } else {
    let value = if frac_div > 1.0 {
      int_part + frac_part / frac_div
    } else {
      int_part
    }
    let mut result = value
    if saw_exp {
      let factor : Double = 10.0
      let mut k = exp_part
      if exp_neg {
        while k > 0 {
          result = result / factor
          k = k - 1
        }
      } else {
        while k > 0 {
          result = result * factor
          k = k - 1
        }
      }
    }
    Some(if neg { -result } else { result })
  }
}

///|
/// Read a symbol (an identifier).
fn read_symbol(r : Reader) -> SExp {
  let buf = StringBuilder()
  while not(r.at_end()) {
    let ch = r.peek()
    if is_symbol_cont(ch) {
      buf.write_char(r.next())
    } else {
      break
    }
  }
  SExp::sym(buf.to_string())
}
