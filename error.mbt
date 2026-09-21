// error.mbt
//
// Error and marker types used by the mblisp interpreter. Three distinct
// errors are exposed:
//
//   - `ReadError`  : the input text could not be tokenised or parsed
//                     into a balanced s-expression.
//   - `EvalError`  : the expression was well-formed but could not be
//                     evaluated (undefined symbol, wrong-arity call,
//                     type mismatch).
//   - `ArityError` : a primitive or user-defined function was called
//                     with the wrong number of arguments.
//
// The variants carry enough information for the REPL and the runnable
// scripts to print a meaningful diagnostic, but they are deliberately
// small so the interpreter stays easy to read.

///|
/// Raised when the reader cannot turn a chunk of source text into
/// balanced s-expressions. The byte offset is the position at which
/// the reader gave up; `expected` describes the token class that would
/// have made progress (e.g. "closing paren", "an atom").
pub suberror ReadError {
  /// Unexpected end of input.
  UnexpectedEOF(String)
  /// A character that does not start any valid token.
  InvalidChar(Int, Char)
  /// The reader expected a closing paren but saw something else.
  UnmatchedParen(Int)
  /// A literal (number, string, ...) could not be parsed.
  InvalidLiteral(Int, String)
}

///|
/// Raised when the evaluator cannot make sense of a syntactically
/// valid s-expression: e.g. an unbound symbol, a non-callable head,
/// or a type error inside a primitive.
pub suberror EvalError {
  /// A symbol has no binding in the current environment chain.
  UnboundSymbol(String)
  /// Attempted to call something that is not a function.
  NotCallable(String)
  /// A type mismatch while applying a primitive.
  TypeMismatch(String, String)
  /// Generic catch-all so callers can raise with a string.
  EvalFailure(String)
}

///|
/// Raised when a primitive or user-defined function is called with
/// the wrong number of arguments.
pub suberror ArityError {
  /// `name` is the operator name, `expected` the required arity, and
  /// `actual` the number of arguments the caller supplied.
  WrongArity(String, Int, Int)
}

///|
/// Convenience: turn a `ReadError` into a single-line diagnostic that
/// includes the byte offset when available.
pub fn ReadError::describe(self : ReadError) -> String {
  match self {
    UnexpectedEOF(what) => "unexpected end of input while reading \{what}"
    InvalidChar(pos, ch) => "invalid character '\{ch}' at byte \{pos}"
    UnmatchedParen(pos) => "unmatched paren at byte \{pos}"
    InvalidLiteral(pos, lit) => "invalid literal '\{lit}' at byte \{pos}"
  }
}

///|
/// Convenience: turn an `EvalError` into a single-line diagnostic.
pub fn EvalError::describe(self : EvalError) -> String {
  match self {
    UnboundSymbol(name) => "unbound symbol '\{name}'"
    NotCallable(what) => "not a callable: \{what}"
    TypeMismatch(what, want) => "type mismatch in \{what}: expected \{want}"
    EvalFailure(msg) => "eval error: \{msg}"
  }
}

///|
/// Convenience: turn an `ArityError` into a single-line diagnostic.
pub fn ArityError::describe(self : ArityError) -> String {
  match self {
    WrongArity(name, expected, actual) =>
      "wrong arity for '\{name}': expected \{expected}, got \{actual}"
  }
}
