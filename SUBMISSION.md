# mblisp 项目申报书

## 1. 项目名称
**mblisp** —— 基于 MoonBit 的 Scheme 子集解释器

## 2. 项目简介
用 MoonBit 从零写的 Scheme 解释器子集实现。代码量约 1.6k 行,无外部 crate,仅依赖 MoonBit 自带的 `ref` 与 `hashmap`。能完整解析 s-expression、构建词法作用域环境、调用 27 个内建原语、求值并打印结果。已用 Y combinator、闭包捕获、递归 fib/factorial、compose 等用例逐个验证过语义,89 个单元测试全部通过。

## 3. 项目方向 / 通用性说明
方向:**嵌入式 DSL 引擎**。

MoonBit 生态目前没有 Lisp 系脚本能力,mblisp 让 MoonBit 应用获得"内置一门脚本语言"的能力,本身不绑定任何具体业务,典型用途包括:

- 配置语言:承载业务规则;
- 规则引擎:跑条件求值;
- 表达式求值器:处理促销、工单、告警里那种嵌套条件;
- 教学工具:演示闭包、Y combinator、λ 演算。

## 4. 预期使用场景(完整 3 例)

**场景 ①:后端告警规则 DSL**

在 MoonBit 后端服务里嵌入 mblisp,运维用 Scheme 写告警逻辑:

```scheme
(if (and (> load-avg 4.0) (> failed-rate 0.1))
    'alert
    'ok)
```

规则变更不需要重启服务,运维改完 .scm 文件,服务 in-process reload 后 mblisp 直接求值。规则可复用 `and / or / not / if / define`,能组合任意复杂的告警表达式。

**场景 ②:程序语言课教学演示**

高校 PL 课上讲 λ 演算、闭包、Y combinator 时,老师在浏览器 wasm 里跑 mblisp 当场演示。学生能亲眼看到 `(define fact ...)` 自递归怎么建立,`(Y (lambda ...))` 怎么用不动点组合子拼出递归,`(define (make-adder n) (lambda (x) (+ x n)))` 怎么捕获 n。这是 PPT 画框图做不到的。

**场景 ③:电商促销表达式**

运营文案经常长这样:"满 200 减 50,VIP 用户再打 8 折,新用户限 1 次"。用 Scheme 维护这种表达式:

```scheme
(define (discount amount user)
  (if (and (>= amount 200) (vip? user) (new? user))
      (* amount 0.4)
      (if (>= amount 200) (- amount 50) amount)))
```

比硬编码 if 链好维护得多,运营改文案不需要发版,前端直接读 .scm 渲染价格。

## 5. 拟实现的核心功能

| 模块 | 功能 |
|------|------|
| Reader | 手写 s-expression lexer/parser,支持 number / string / symbol / bool / list / dotted-pair / quote |
| Environment | 链式 immutable Env,提供 bind / assign / child / lookup |
| 9 个 special form | quote / if / define / set! / lambda / let / let* / cond / begin |
| 27 个 primitive | 算术(+/-/*//)、比较(=、<、>)、<=、>=)、谓词(null?、pair?、number?、eq? 等)、列表操作(cons/car/cdr/list/length/append/reverse)、I/O(display/print/number->string) |
| 闭包 | 编码为 `(params body . env_marker)`,marker 重绑实现 define 自递归 |
| 入口 API | `eval_top(src) -> SExp raise`,REPL、CLI、嵌入式调用统一走这一个函数 |
| 测试 | 89 个单元测试,覆盖 SExp / reader / env / primitives / eval 全栈,CI 跑过 |

## 6. 项目性质
**原创项目**。解释器整体从零写起,未参考具体的"Lisp-in-X"开源项目。

## 7. 移植 / 参考说明
**不适用**。唯一有据可查的参考是:
- MoonBit 官方文档与 stdlib API(`moonbitlang/core` 的 `ref`、`hashmap`);
- R5RS Scheme 标准中对核心语法与语义部分的公共规范引用。

这些都是公共规范引用,不属于移植,不构成对任何具体开源项目的复刻或派生。