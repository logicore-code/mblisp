# mblisp 项目方案说明

> MoonBit 九月开源大赛 2026 参赛项目 · `logicore-code/mblisp`
>
> 原报名方向 `mbcrdt`（CRDT 实现）经复审认为与仓库中已有的
> `Juwan-Hwang/moon-certified`、 `dowdiness/event-graph-walker` 等作品
> 主题重叠，改为提交 `mblisp` —— 一个用纯 MoonBit 编写的 Scheme/Lisp
> 解释器。

## 1. 项目描述（What）

`mblisp` 是一个**完全使用 MoonBit 语言**编写的 Scheme 解释器子集实现。
它能从零读取一段 Scheme 源码并执行求值，最终把结果以 s-expression
形式输出。仓库包含：

- 解释器核心库（`logicore-code/mblisp`），约 1.6k 行 MoonBit 源码；
- 89 个单元测试，覆盖 SExp ADT、reader、environment、primitives、eval 全栈；
- 6 个可运行的 example 程序，分别演示递归、闭包、高阶函数、Y combinator
  等特性；
- 一个 `cmd/repl` 命令行入口；
- 一份 Apache-2.0 开源许可协议；
- GitHub Actions 流水线（`moon check` / `moon test` / `moon fmt --check`）。

仓库根目录没有任何原生依赖，运行时只需 MoonBit 自带的 `moonbitlang/core`
（用到 `ref` 与 `hashmap` 两个包），wasm / wasm-gc / js / native 四种
目标都能编译通过。

## 2. 解决的问题（Why）

Lisp / Scheme 在编程语言史上是一个独特的存在：语法极简（整个语言
只需要 s-expression 一种结构）、同像性（代码即数据）、一等公民的函数、
λ 演算语义清晰。MoonBit 社区目前还没有一个可用的 Scheme 解释器；
`mblisp` 填补了这个空白，让 MoonBit 用户能在自己的程序里嵌入一个
小型 Lisp 脚本引擎 —— 比如做配置、做规则引擎、做教学演示。

同时，本项目也对 MoonBit 语言本身做了一次"自循环"验证：

- MoonBit 的 `suberror` 模型如何承担错误传播；
- MoonBit 的 enum + match 如何表达一个真实的 ADT；
- MoonBit 的 `HashMap` / `Ref` 如何承担运行时元数据；
- MoonBit 的 `derive(Debug)` + `assert_eq` 测试约定是否舒服。

项目作者在学习 MoonBit 的过程中顺手把所有这些机制都跑了一遍。

## 3. 目标用户（Who）

| 角色 | 他们能用 `mblisp` 做什么 |
| --- | --- |
| MoonBit 应用开发者 | 在自己的 wasm/wasm-gc 项目里嵌入一个可脚本化的 DSL |
| MoonBit 语言学习者 | 通过读 `eval.mbt` 看一个真实解释器怎么写 |
| 教学场景 | 用 `examples/y_combinator.mbt` 现场跑 Y combinator |
| 其他贡献者 | 在 `primitives.mbt` 里加新 primitive，在 `examples/` 里加新脚本 |

## 4. 如何使用（How）

构建 / 测试：

```bash
moon test            # 89/89 通过
moon check           # 类型检查通过，0 errors
moon fmt --check     # 格式检查
moon run examples/factorial --target native
moon run cmd/repl               --target native
```

在自己的项目里调用：

```moonbit
import { "logicore-code/mblisp" }

fn main {
  let src = "(+ 1 2 (* 3 4))"
  let v = try @mblisp.eval_top(src) catch { _ => return } noraise { x => x }
  println(v.to_string())   // → 21
}
```

## 5. 关键技术决策

- **Persistent environment**：`eval` 返回 `(env, value)` 元组，让
  `define / set! / let / let*` 能跨顶层表达式串成一条链；
- **闭包 = SExp 数据**：`(params body . env_marker)`，marker 在
  全局 `env_table` 中反查到捕获的 `Env`，使闭包可以安全地穿越 mutation；
- **`define` 自递归**：构造 closure 时先占位一个 marker，构造完成后
  再把 marker 重新绑定到"已经包含此 closure"的 env；
- **保留字规避**：MoonBit 0.1.20260915 预留了 `extend / define / set`，
  所以 MoonBit 侧的 API 改为 `Env::child / Env::bind / Env::assign`，
  Scheme 侧的 `define` 通过 `eval_pair` 里的 `match name` 来分发。

## 6. 路线图

短期（v0.2）：

- `letrec` 与 named-let；
- 字符串/向量内建原语；
- 一个真正的 interactive REPL（当前 MoonBit native runtime 没有 byte-level
  stdin API，需要等待运行时支持）。

中期（v0.3+）：

- 尾调用优化；
- 简单的 macro 系统；
- 字节码编译 + register-based VM 后端。

## 7. 参赛承诺

- 代码全部自写于本仓库，参考的 MoonBit 教程已注明；
- 不与现有 CRDT 类项目主题重叠；
- 全部源码以 Apache-2.0 发布；
- CI 已配置；只要 `logicore-code` 这个 GitHub 账号可访问，10 次以上
  原子提交都将保留在主分支上。