// Embedding demo: a tiny mock router that uses mblisp to decide
// whether an HTTP request matches a routing rule.
//
// The shape mimics what a real backend service would do: a list
// of `Rule` records where each rule has a Scheme predicate. To
// route a request we evaluate the predicate in a fresh
// environment populated with the request's fields, and if it
// returns `#t` the rule "fires".
//
// This is a standalone demo: no real HTTP server, no real JSON
// parser. We just construct a sample `Request` value and walk
// through three rules to show the pattern end-to-end.
//
// Note: bare symbols in the rule bodies (`'admin`, `'POST`, etc.)
// are quoted so the evaluator treats them as literal symbols
// rather than variable lookups.

///|
struct Request {
  http_method : String
  url_path : String
  user_role : String
  is_authenticated : Bool
}

///|
struct Rule {
  name : String
  script : String
}

///|
fn evaluate_predicate(rule : Rule, req : Request) -> Bool {
  // Build an env that knows about the request fields, then
  // run the rule's predicate. `Env::bind` returns a fresh env
  // (the original is immutable), so we thread the new env
  // through each call.
  let mut env : @mblisp.Env = @mblisp.Env::new()
  // Strip leading "/" from the path so the rule can compare
  // against a bare symbol like `'health`.
  let path_part = if req.url_path.length() > 0 && req.url_path[0] == '/' {
    String::unsafe_substring(req.url_path, start=1, end=req.url_path.length())
  } else {
    req.url_path
  }
  env = env.bind("method", @mblisp.SExp::sym(req.http_method))
  env = env.bind("path", @mblisp.SExp::sym(path_part))
  env = env.bind("user-role", @mblisp.SExp::sym(req.user_role))
  env = env.bind(
    "authenticated?",
    if req.is_authenticated {
      @mblisp.SExp::bool_true()
    } else {
      @mblisp.SExp::bool_false()
    },
  )
  let result = try @mblisp.eval_top(rule.script, env~) catch {
    _ => @mblisp.SExp::bool_false()
  } noraise {
    v => v
  }
  @mblisp.SExp::equal(result, @mblisp.SExp::bool_true())
}

///|
fn main {
  let admin_write_script =
    #| (if (if (if authenticated?
    #|             (eq? user-role 'admin)
    #|             #f)
    #|         (eq? method 'POST)
    #|         #f)
    #|     #t
    #|     #f)
  let health_check_script =
    #| (eq? path 'health)
  let public_read_script =
    #| (eq? method 'GET)
  let rules : Array[Rule] = [
    { name: "admin-write", script: admin_write_script },
    { name: "health-check", script: health_check_script },
    { name: "public-read", script: public_read_script },
  ]
  let requests : Array[Request] = [
    { http_method: "POST", url_path: "/users", user_role: "admin", is_authenticated: true },
    { http_method: "POST", url_path: "/users", user_role: "user", is_authenticated: true },
    { http_method: "GET", url_path: "/posts/123", user_role: "user", is_authenticated: false },
    { http_method: "GET", url_path: "/health", user_role: "system", is_authenticated: false },
  ]
  println("| mblisp embed demo: rule-based request routing")
  println("| -------------------------------------------")
  for req in requests {
    let mut matched = "(no rule)"
    for rule in rules {
      if evaluate_predicate(rule, req) {
        matched = rule.name
        break
      }
    }
    println(
      "| \{req.http_method} \{req.url_path} (role=\{req.user_role}, auth=\{req.is_authenticated}) => " +
      matched,
    )
  }
}