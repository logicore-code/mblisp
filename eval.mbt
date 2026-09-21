// eval.mbt
//
// The evaluator. Given an `SExp` and an `Env`, it returns the new
// environment (with any define / set! / let bindings applied) plus
// the value of the expression. The persistent-environment shape
// keeps `eval` easy to reason about and makes top-level scripting
// (`eval_top`) trivial to thread.
//
// Special forms (`quote`, `if`, `define`, `set!`, `lambda`, `let`,
// `let*`, `cond`, `begin`) are handled inline as a big `match` on
// the head of each application. Anything else is looked up in the
// environment and dispatched to either a primitive (matched by tag)
// or a user-defined closure.
//
// Closures are represented as `SExp::Cons(params, SExp::Cons(body,
// env_marker))`. The body is a single expression; multi-expression
// bodies are wrapped implicitly in `(begin ...)`.

///|
/// Result of evaluating one expression: the updated environment and
/// the value produced. Returning the environment alongside the value
/// is what lets `define` / `set!` / `let` persist across top-level
/// forms.
pub struct EvalResult {
  env : Env
  value : SExp
} derive(Debug)

///|
/// A user-defined closure: `(params body . env_marker)` where `params`
/// is a list of symbols (or a single symbol for `(lambda x ...)`),
/// `body` is the expression to evaluate when the closure is applied,
/// and `env_marker` is a marker symbol that looks up the captured
/// environment in the global `env_table`.
pub fn make_closure(params : SExp, body : SExp, env : Env) -> SExp {
  let marker = register_env(env)
  SExp::cons(params, SExp::cons(body, SExp::sym(marker)))
}

///|
/// Allocate a fresh marker for `env` and store `env` in the table
/// under that marker. Used when we need to attach the same marker
/// to multiple closures (e.g. mutually recursive `define`s).
pub fn register_env(env : Env) -> String {
  let counter = env_counter.val
  env_counter.val = counter + 1
  let id = "__env__:" + counter.to_string()
  env_table.set(id, env)
  id
}

///|
/// Replace the env that `marker` points at. Used by `define` to
/// splice the just-created closure into the captured environment
/// so recursive calls inside the body can find it.
pub fn rebind_env(marker : String, env : Env) -> Unit {
  env_table.set(marker, env)
}

///|
/// Internal counter used to give each `Env` a unique marker.
let env_counter : @ref.Ref[Int] = @ref.new(0)

///|
/// Global map from marker symbols back to environments.
let env_table : @hashmap.HashMap[String, Env] = @hashmap.HashMap([])

///|
fn env_from_marker(marker : SExp) -> Env? {
  match marker {
    Sym(s) if s.has_prefix("__env__:") => env_table.get(s)
    _ => None
  }
}

///|
/// Evaluate `expr` in `env`. Special forms are handled inline;
/// everything else is dispatched via `apply`.
pub fn eval(expr : SExp, env : Env) -> EvalResult raise {
  match expr {
    Num(_) | Str(_) | Bool(_) => EvalResult::{ env, value: expr, }
    Nil => EvalResult::{ env, value: expr, }
    Sym(name) =>
      match env.lookup(name) {
        Some(v) => EvalResult::{ env, value: v, }
        None => raise UnboundSymbol(name)
      }
    Cons(head, rest) => eval_pair(head, rest, env)
  }
}

///|
/// Evaluate every top-level expression in `src` against the given
/// (default: fresh) global environment, threading each form's
/// updated environment into the next one. Returns the value of the
/// last form (or `()` if `src` was empty).
pub fn eval_top(src : String, env? : Env = Env::new()) -> SExp raise {
  let mut current = env
  let exprs = read_all(src)
  let mut last_value = SExp::nil()
  let mut last_env = current
  for e in exprs {
    let r = eval(e, current)
    last_env = r.env
    last_value = r.value
    current = r.env
  }
  ignore(last_env)
  last_value
}

///|
/// Helper: dispatch on the operator of a `(head . rest)` pair.
fn eval_pair(head : SExp, rest : SExp, env : Env) -> EvalResult raise {
  match head {
    Sym(name) =>
      match name {
        "quote" => {
          // (quote x) — return x unevaluated.
          let items = rest.to_array()
          if items.length() != 1 {
            raise ArityError::WrongArity("quote", 1, items.length())
          }
          EvalResult::{ env, value: items[0], }
        }
        "if" => eval_if(rest, env)
        "define" => eval_define(rest, env)
        "set!" => eval_setbang(rest, env)
        "lambda" => eval_lambda(rest, env)
        "let" => eval_let(rest, env)
        "let*" => eval_letstar(rest, env)
        "cond" => eval_cond(rest, env)
        "begin" => eval_begin(rest, env)
        _ =>
          // Plain symbol operator. If it names a primitive we apply
          // directly; otherwise we look it up in `env` and apply the
          // result (which is what makes user-defined functions work).
          if is_primitive_name(name) {
            let args : Array[SExp] = eval_args(rest, env)
            let applied = prim_dispatch(name, args)
            EvalResult::{ env, value: applied, }
          } else {
            eval_application(head, rest, env)
          }
      }
    _ => eval_application(head, rest, env)
  }
}

///|
/// `(if cond then else?)` — three-arg form with optional else.
fn eval_if(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() < 2 || items.length() > 3 {
    raise ArityError::WrongArity("if", 2, items.length())
  }
  let cond = eval(items[0], env).value
  if truthy(cond) {
    eval(items[1], env)
  } else if items.length() == 3 {
    eval(items[2], env)
  } else {
    // No else clause and condition is false: return unspecified,
    // which we represent as `()` for compatibility with Scheme.
    EvalResult::{ env, value: SExp::nil(), }
  }
}

///|
/// `(define name expr)` — bind `name` in `env`. `name` may be either
/// a symbol or a list `(name params...)` for short-form
/// `(define (f x) body)`. In the short form `items[1]` is the body.
/// For short-form `define`, the function name is recursively
/// visible inside its own body — to get that, we pre-bind the
/// closure (which captures `env`) into `env` before constructing
/// the closure itself.
fn eval_define(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() != 2 {
    raise ArityError::WrongArity("define", 2, items.length())
  }
  match items[0] {
    Sym(name) => {
      // Plain `(define name expr)`. The expression may reference
      // `name` itself (e.g. `(define ones (lambda () (cons 1 ones)))`),
      // so we pre-bind `name` to a placeholder in the environment
      // before evaluating the rhs, then replace that placeholder
      // with the actual value afterwards.
      let marker = register_env(env)
      let placeholder = SExp::sym(marker)
      let env_with_self = env.bind(name, placeholder)
      rebind_env(marker, env_with_self)
      let r = eval(items[1], env_with_self)
      let final_env = r.env.assign(name, r.value)
      EvalResult::{ env: final_env, value: r.value, }
    }
    Cons(head_sym, params_cell) =>
      match head_sym {
        Sym(name) => {
          // `(define (name x y) body)`. To make the function
          // recursive inside its own body we need the closure to
          // capture an environment that already contains the
          // binding `name -> closure`. We achieve that by
          // allocating a fresh marker, building the closure with
          // that marker, then patching the marker to point at the
          // extended environment.
          let marker = register_env(env)
          let closure = SExp::cons(
            params_cell,
            SExp::cons(items[1], SExp::sym(marker)),
          )
          let env_with_self = env.bind(name, closure)
          rebind_env(marker, env_with_self)
          EvalResult::{ env: env_with_self, value: closure, }
        }
        _ => raise EvalFailure("define: invalid function head")
      }
    _ => raise EvalFailure("define: invalid name")
  }
}

///|
/// `(set! name expr)` — assign to an existing binding.
fn eval_setbang(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() != 2 {
    raise ArityError::WrongArity("set!", 2, items.length())
  }
  match items[0] {
    Sym(name) => {
      let r = eval(items[1], env)
      EvalResult::{ env: r.env.assign(name, r.value), value: r.value, }
    }
    _ => raise EvalFailure("set!: name must be a symbol")
  }
}

///|
/// `(lambda params body)` — produce a closure.
fn eval_lambda(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() != 2 {
    raise ArityError::WrongArity("lambda", 2, items.length())
  }
  let closure = make_closure(items[0], items[1], env)
  EvalResult::{ env, value: closure, }
}

///|
/// `(let ((name val) ...) body)` — local bindings. The body is
/// evaluated in a child frame of `env` containing all the new
/// bindings.
fn eval_let(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() != 2 {
    raise ArityError::WrongArity("let", 2, items.length())
  }
  let mut child = Env::child(env)
  let bindings = items[0].to_array()
  for b in bindings {
    match b {
      Cons(name, Cons(value, Nil)) =>
        match name {
          Sym(n) => {
            let r = eval(value, child)
            child = r.env.bind(n, r.value)
          }
          _ => raise EvalFailure("let: invalid binding name")
        }
      _ => raise EvalFailure("let: invalid binding form")
    }
  }
  let r = eval(items[1], child)
  EvalResult::{ env, value: r.value, }
}

///|
/// `(let* ((name val) ...) body)` — sequential local bindings. Each
/// binding sees the previous ones.
fn eval_letstar(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() != 2 {
    raise ArityError::WrongArity("let*", 2, items.length())
  }
  let mut child = Env::child(env)
  let bindings = items[0].to_array()
  for b in bindings {
    match b {
      Cons(name, Cons(value, Nil)) =>
        match name {
          Sym(n) => {
            let r = eval(value, child)
            child = r.env.bind(n, r.value)
          }
          _ => raise EvalFailure("let*: invalid binding name")
        }
      _ => raise EvalFailure("let*: invalid binding form")
    }
  }
  eval(items[1], child)
}

///|
/// `(cond (test body...) ... [(else body...)])` — chain of tests.
fn eval_cond(rest : SExp, env : Env) -> EvalResult raise {
  let clauses = rest.to_array()
  if clauses.length() == 0 {
    raise EvalFailure("cond: needs at least one clause")
  }
  let mut last = SExp::nil()
  let mut last_env = env
  for clause in clauses {
    let items = clause.to_array()
    if items.length() == 0 {
      raise EvalFailure("cond: empty clause")
    }
    match items[0] {
      Sym("else") => {
        let r = eval_begin(SExp::from_array(items[1:].to_owned()), env)
        return r
      }
      _ => {
        let r = eval(items[0], env)
        if truthy(r.value) {
          let body_r = eval_begin(SExp::from_array(items[1:].to_owned()), r.env)
          return body_r
        }
        last = SExp::nil()
        last_env = r.env
      }
    }
  }
  EvalResult::{ env: last_env, value: last, }
}

///|
/// `(begin expr ...)` — evaluate each expression in order; return
/// the last value along with the final environment.
fn eval_begin(rest : SExp, env : Env) -> EvalResult raise {
  let items = rest.to_array()
  if items.length() == 0 {
    EvalResult::{ env, value: SExp::nil(), }
  } else {
    let mut current = env
    let mut last = SExp::nil()
    for item in items {
      let r = eval(item, current)
      current = r.env
      last = r.value
    }
    EvalResult::{ env: current, value: last, }
  }
}

///|
/// Evaluate a function application: `(head arg1 arg2 ...)`.
fn eval_application(head : SExp, rest : SExp, env : Env) -> EvalResult raise {
  let proc_r = eval(head, env)
  let values = eval_args(rest, proc_r.env)
  let applied = apply(proc_r.value, values)
  EvalResult::{ env: proc_r.env, value: applied, }
}

///|
/// Evaluate each expression in `rest` to a value, threading the
/// environment through. Used both for primitive calls and user
/// function calls so that nested `define`s in argument positions
/// would persist (we don't actually rely on that today but the
/// behaviour is well-defined).
fn eval_args(rest : SExp, env : Env) -> Array[SExp] raise {
  let args = rest.to_array()
  let values : Array[SExp] = []
  let mut current = env
  for arg in args {
    let r = eval(arg, current)
    current = r.env
    values.push(r.value)
  }
  values
}

///|
/// Apply `proc` to the already-evaluated `args`. Dispatches to
/// primitives by tag; otherwise treats `proc` as a closure.
pub fn apply(proc : SExp, args : Array[SExp]) -> SExp raise {
  // Primitive dispatch by marker symbol.
  match proc {
    Sym(name) if is_primitive_name(name) => prim_dispatch(name, args)
    Sym(name) => raise NotCallable(name)
    _ => apply_closure(proc, args)
  }
}

///|
/// Look up `name` against the primitive registry. Returns `None`
/// for non-primitive symbols; otherwise dispatches and returns the
/// result or re-raises any arity / type error.
fn prim_dispatch(name : String, args : Array[SExp]) -> SExp raise {
  prim_dispatch_unsafe(name, args)
}

///|
/// `true` iff `name` is a primitive we know how to dispatch. Used
/// by the evaluator to decide whether to apply a symbol operator as
/// a primitive even when it has not been bound in the environment.
fn is_primitive_name(name : String) -> Bool {
  match name {
    "+"
    | "-"
    | "*"
    | "/"
    | "="
    | "<"
    | ">"
    | "<="
    | ">="
    | "null?"
    | "pair?"
    | "number?"
    | "symbol?"
    | "string?"
    | "boolean?"
    | "eq?"
    | "cons"
    | "car"
    | "cdr"
    | "list"
    | "length"
    | "append"
    | "reverse"
    | "display"
    | "print"
    | "number->string" => true
    _ => false
  }
}

///|
fn prim_dispatch_unsafe(name : String, args : Array[SExp]) -> SExp raise {
  match name {
    "+" => prim_add(args)
    "-" => prim_sub(args)
    "*" => prim_mul(args)
    "/" => prim_div(args)
    "=" => prim_eq(args)
    "<" => prim_lt(args)
    ">" => prim_gt(args)
    "<=" => prim_le(args)
    ">=" => prim_ge(args)
    "null?" => prim_nullp(args)
    "pair?" => prim_pairp(args)
    "number?" => prim_numberp(args)
    "symbol?" => prim_symbolp(args)
    "string?" => prim_stringp(args)
    "boolean?" => prim_booleanp(args)
    "eq?" => prim_eqp(args)
    "cons" => prim_cons(args)
    "car" => prim_car(args)
    "cdr" => prim_cdr(args)
    "list" => prim_list(args)
    "length" => prim_length(args)
    "append" => prim_append(args)
    "reverse" => prim_reverse(args)
    "display" => prim_display(args)
    "print" => prim_print(args)
    "number->string" => prim_number_to_string(args)
    _ => raise NotCallable(name)
  }
}

///|
/// Apply a closure to its arguments, matching parameter shapes and
/// building a new child frame.
fn apply_closure(proc : SExp, args : Array[SExp]) -> SExp raise {
  match proc {
    Cons(params, rest) =>
      match rest {
        Cons(body, env_marker) =>
          match env_from_marker(env_marker) {
            Some(closure_env) => {
              let child = bind_params(params, args, closure_env)
              let r = eval(body, child)
              r.value
            }
            None => raise EvalFailure("closure: missing captured environment")
          }
        _ => raise EvalFailure("closure: malformed")
      }
    _ => raise NotCallable(proc.to_string())
  }
}

///|
/// Bind `args` to `params` in a fresh child of `closure_env`. Supports
/// three parameter shapes:
///
///   - `(x y ...)`     — list of symbols, exact arity required.
///   - `x`              — single symbol, binds the entire arg list.
///   - `(x y . rest)`  — variadic, `rest` binds the remaining args.
fn bind_params(
  params : SExp,
  args : Array[SExp],
  closure_env : Env,
) -> Env raise {
  let mut child = Env::child(closure_env)
  // `(lambda x body)` — `x` binds the whole argument list.
  match params {
    Sym(name) => {
      child = child.bind(name, SExp::from_array(args))
      return child
    }
    _ => ()
  }
  // Otherwise `params` is a list. Walk it to find the variadic tail.
  let fixed : Array[String] = []
  let mut variadic : String? = None
  let mut cur = params
  while true {
    match cur {
      Nil => break
      Cons(Sym(n), rest) => {
        fixed.push(n)
        cur = rest
      }
      Cons(_, _) => raise EvalFailure("closure: parameter must be a symbol")
      Sym(rest_name) => {
        // Improper tail: `(x y . rest)` produces this case at the
        // very end of the list.
        variadic = Some(rest_name)
        break
      }
      _ => raise EvalFailure("closure: malformed parameter list")
    }
  }
  let fixed_count = fixed.length()
  let min_required = fixed_count
  let max_required = match variadic {
    Some(_) => -1 // variadic accepts arbitrarily many
    None => fixed_count
  }
  if args.length() < min_required {
    raise ArityError::WrongArity("<closure>", min_required, args.length())
  }
  if max_required >= 0 && args.length() > max_required {
    raise ArityError::WrongArity("<closure>", max_required, args.length())
  }
  for i in 0..<fixed_count {
    child = child.bind(fixed[i], args[i])
  }
  match variadic {
    Some(rest_name) =>
      child = child.bind(
        rest_name,
        SExp::from_array(args[fixed_count:].to_owned()),
      )
    None => ()
  }
  child
}

///|
/// `true` for anything that is *not* the boolean `#f`. In Scheme,
/// every value except `#f` is truthy, including `0` and `()`.
fn truthy(v : SExp) -> Bool {
  !SExp::equal(v, SExp::bool_false())
}
