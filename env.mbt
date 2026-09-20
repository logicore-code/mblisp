// env.mbt
//
// The lexical environment is the runtime symbol table. Bindings are
// stored in a per-frame `Map` and chained through a `parent` pointer;
// looking up a name walks the chain outward. This is the standard
// Scheme closure model: a closure captures the environment that was
// active at the time of `lambda`, which keeps lexical scoping
// consistent.

///|
/// A single lexical scope. Each `Env` owns a map of bindings and an
/// optional pointer to the enclosing scope; bindings added with
/// `bind` shadow outer bindings of the same name without mutating
/// them.
pub struct Env {
  bindings : Map[String, SExp]
  parent : Env?
} derive(Debug)

///|
/// Build the global (top-level) environment. The global frame has no
/// parent.
pub fn Env::new() -> Env {
  { bindings: Map([]), parent: None, }
}

///|
/// Build a new frame whose parent is `parent`. New bindings land in
/// the new frame; lookups fall through to `parent` if the name is
/// missing here.
pub fn Env::child(parent : Env) -> Env {
  { bindings: Map([]), parent: Some(parent), }
}

///|
/// `true` iff `self` is the global environment (no parent).
pub fn Env::self_is_global(self : Env) -> Bool {
  match self.parent {
    Some(_) => false
    None => true
  }
}

///|
/// Look up `name` in the current frame, then walk outward. Returns
/// `None` if the name has no binding in the whole chain.
pub fn Env::lookup(self : Env, name : String) -> SExp? {
  match self.bindings.get(name) {
    Some(v) => Some(v)
    None =>
      match self.parent {
        Some(p) => p.lookup(name)
        None => None
      }
  }
}

///|
/// Insert `name -> value` into the current frame. Shadows any
/// existing binding for `name` in the current frame; outer frames are
/// untouched.
pub fn Env::bind(self : Env, name : String, value : SExp) -> Env {
  let bindings : Map[String, SExp] = Map([])
  for k, v in self.bindings {
    bindings.set(k, v)
  }
  bindings.set(name, value)
  {
    bindings,
    parent: match self.parent {
      Some(p) => Some(p)
      None => None
    },
  }
}

///|
/// Assign to `name` in whichever frame first defines it. Because the
/// interpreter treats environments as persistent values, `assign`
/// returns a new chain: the original `self` is unchanged, and the
/// returned `Env` has every frame from this one up to the defining
/// frame rebuilt. If `name` is unbound, the returned value is `self`
/// unchanged.
pub fn Env::assign(self : Env, name : String, value : SExp) -> Env {
  if self.bindings.contains(name) {
    let bindings : Map[String, SExp] = Map([])
    for k, v in self.bindings {
      bindings.set(k, v)
    }
    bindings.set(name, value)
    {
      bindings,
      parent: match self.parent {
        Some(p) => Some(p)
        None => None
      },
    }
  } else {
    match self.parent {
      Some(p) =>
        match p.assign(name, value) {
          new_parent => { bindings: self.bindings, parent: Some(new_parent), }
        }
      None => self
    }
  }
}

///|
/// Number of bindings in the current frame (does not count parents).
pub fn Env::local_size(self : Env) -> Int {
  self.bindings.length()
}

///|
/// Total number of bindings reachable through this environment,
/// including all parent frames. Useful for debugging and tests.
pub fn Env::total_size(self : Env) -> Int {
  match self.parent {
    None => self.local_size()
    Some(p) => self.local_size() + p.total_size()
  }
}

///|
/// Snapshot the bindings as `(name . value)` pairs, only the current
/// frame. Useful for tests and debugging.
pub fn Env::to_list(self : Env) -> SExp {
  let items : Array[SExp] = []
  for k, v in self.bindings {
    items.push(SExp::cons(SExp::sym(k), v))
  }
  SExp::from_array(items)
}
