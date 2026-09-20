// Module configuration for mblisp, a small Scheme/Lisp interpreter written
// in pure MoonBit. The interpreter implements a sufficient subset of
// Scheme to evaluate the bundled example programs, including lexical
// scoping, closures, `lambda`, `let`, recursion, list operations and a
// handful of arithmetic / comparison primitives. The goal is to be a
// readable reference implementation rather than a production-grade
// runtime.
//
// Learn more at https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "logicore-code/mblisp"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/logicore-code/mblisp"

license = "Apache-2.0"

keywords = [ "lisp", "scheme", "interpreter", "s-expression", "dsl", "wasm" ]

preferred_target = "wasm"

description = "A pure-MoonBit Scheme/Lisp interpreter: s-expression reader, lexical-scope environment, eval/apply core, primitive library, REPL and bundled example scripts. Runs on wasm/wasm-gc/js/native with zero external dependencies beyond the MoonBit core prelude."
