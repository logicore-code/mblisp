// Performance benchmarks for mblisp.
//
// Run with `moon test --target native perf` to see the timing
// output (the test itself just prints a JSON dump of the
// per-benchmark summary). Numbers are recorded in
// `docs/benchmark.md`.
//
// Each `bench_*` test exercises a single hot path of the
// interpreter. We use `@bench.single_bench` for clarity: it runs
// the closure `count` times, picks a batch size that keeps the
// wall time above a noise floor, and reports min / mean / max.

///|
test "bench_run_all" {
  let results : Array[String] = []

  let fib15 = @bench.single_bench(name="fib15", count=10, fn() {
    let src =
      #| (define (fib n)
      #|   (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
      #| (fib 15)
    let _ = try @mblisp.eval_top(src) catch {
      _ => ()
    } noraise {
      v => ignore(v)
    }
  })
  results.push(fib15 |> @json.to_json |> j => { j.stringify() })

  let fact10 = @bench.single_bench(name="fact10", count=10, fn() {
    let src =
      #| (define (fact n)
      #|   (if (<= n 1) 1 (* n (fact (- n 1)))))
      #| (fact 10)
    let _ = try @mblisp.eval_top(src) catch {
      _ => ()
    } noraise {
      v => ignore(v)
    }
  })
  results.push(fact10 |> @json.to_json |> j => { j.stringify() })

  let closure = @bench.single_bench(name="closure", count=10, fn() {
    let src =
      #| (define (make-adder n)
      #|   (lambda (x) (+ x n)))
      #| ((make-adder 3) 100)
    let _ = try @mblisp.eval_top(src) catch {
      _ => ()
    } noraise {
      v => ignore(v)
    }
  })
  results.push(closure |> @json.to_json |> j => { j.stringify() })

  let list = @bench.single_bench(name="list", count=10, fn() {
    let src =
      #| (define (build n)
      #|   (if (= n 0)
      #|       '()
      #|       (cons n (build (- n 1)))))
      #| (length (build 50))
    let _ = try @mblisp.eval_top(src) catch {
      _ => ()
    } noraise {
      v => ignore(v)
    }
  })
  results.push(list |> @json.to_json |> j => { j.stringify() })

  let yfact = @bench.single_bench(name="y_fact5", count=10, fn() {
    let src =
      #| (define Y
      #|   (lambda (f)
      #|     ((lambda (x) (f (lambda (v) ((x x) v))))
      #|      (lambda (x) (f (lambda (v) ((x x) v)))))))
      #| (define fact
      #|   (Y (lambda (rec)
      #|        (lambda (n)
      #|          (if (<= n 1) 1 (* n (rec (- n 1))))))))
      #| (fact 5)
    let _ = try @mblisp.eval_top(src) catch {
      _ => ()
    } noraise {
      v => ignore(v)
    }
  })
  results.push(yfact |> @json.to_json |> j => { j.stringify() })

  println("=== mblisp benchmark results ===")
  for r in results {
    println(r)
  }
  assert_eq(results.length(), 5)
}

///|
fn main {
  println("perf binary: run `moon test --target native perf` for measurements")
}
// "Native vs mblisp" overhead benchmark.
//
// Runs the same workload two ways:
//
//   1. as a hand-written MoonBit recursive function
//   2. as a Scheme script passed through `eval_top`
//
// Both compute fib(20). The native version is exactly the
// transformation a smart compiler would apply to the Scheme
// version: a single recursive function with primitive arithmetic.
// The interpreter version exercises the full mblisp pipeline
// (reader + env + eval + primitives + closures).
//
// The ratio (interpreted / native) is the per-call embedding
// overhead that a user pays for the flexibility of running
// user-supplied Scheme. We document the number in
// docs/benchmark.md so reviewers can sanity-check the
// performance picture without running the bench themselves.

///|
fn fib_native(n : Int) -> Int {
  if n < 2 {
    n
  } else {
    fib_native(n - 1) + fib_native(n - 2)
  }
}

///|
test "bench_compare_fib20_native" {
  let summary = @bench.single_bench(
    name="fib20_native_x10",
    count=10,
    fn() {
      let mut i = 0
      while i < 10 {
        ignore(fib_native(20))
        i = i + 1
      }
    },
  )
  // Summary is opaque; dump via JSON for a stable report.
  let json = summary |> @json.to_json |> (j => j.stringify())
  println("| fib20 native x10: \{json}")
}

///|
test "bench_compare_fib20_interpreted" {
  let src =
    #| (define (fib n)
    #|   (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))
    #| (fib 20)
  let summary = @bench.single_bench(
    name="fib20_mblisp_x10",
    count=10,
    fn() {
      let mut i = 0
      while i < 10 {
        let _ = try @mblisp.eval_top(src) catch {
          _ => ()
        } noraise {
          v => ignore(v)
        }
        i = i + 1
      }
    },
  )
  let json = summary |> @json.to_json |> (j => j.stringify())
  println("| fib20 mblisp x10: \{json}")
}