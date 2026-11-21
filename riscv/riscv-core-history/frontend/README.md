# frontend

`frontend` 实现 [`../MODULES.md`](../MODULES.md) 的前端部分：

```text
(file name form ...) ...
        │
        ▼
collect   只收集模块、定义、data/raw label、顶层顺序
        │
        ▼
link      只算 imports / exports 的不动点，查冲突
        │
        ▼
rewrite   只把本地链换成完整链
        │
        ▼
(func ...) / (data ...) / (raw ...)
+ exports（完整链，单独返回）
```

它不验证 virtual IR，不做 allocation，不碰布局/编码。

## 文件

| 文件 | 只关心 |
| --- | --- |
| `sexp.rkt` | 名字、链、form、`($ x)` / `(native xN)` / `(global chain)`、raw 的 label 位置表 |
| `program.rkt` | 前端中间记录；唯一的名字解析函数 `resolve-local` |
| `collect.rkt` | 顶层 form 的壳、模块表、定义表、data/raw label、源码顺序 |
| `link.rkt` | require / provide / prefix / rename / re-export / 循环 require |
| `rewrite.rkt` | 把 `(global chain)`、data/raw label、raw 控制目标换成完整链 |
| `main.rkt` | `resolve-program` / `resolve-files` / `resolve-files-with-interfaces` |

## 入口

```racket
(require "frontend/main.rkt")

;; 单文件：forms 是顶层 form 的列表
(resolve-program forms)
;; => (values resolved-items exports)

;; 多文件：每个文件是 (file name form ...)
(resolve-files files)
;; => (values resolved-items exports)
```

- `resolved-items` 顶层只有 `func` / `data` / `raw`。
- `resolve-files-with-interfaces` 额外返回 extern 表；interface source 不产生 unit。
- `exports` 是完整全局链，已去重排序。
- 文件标签 `(file ...)` 只用于错误消息，不进入输出。

## 不变量

1. 前端输入里的全局引用写本地链；输出里全是完整链。
2. 输出没有 `module` / `provide` / `require` / 文件名。
3. `($ name)`、block 名、inline `asm.code` 里的裸 label 不参与模块解析。
4. `asm` 整体原样保留；它是封闭 machine 块。
5. raw / data 内部的 label 是模块作用域的全局名。
6. data body 里的 `(label ...)` 和 `(global chain)` 都要解析。
7. 所有判断用 `match` / `assoc` / `hash`，不做字符串前缀解析。

## 已定的前端规则

对应 [`../REVIEW.md`](../REVIEW.md) 的 3.4。

| 问题 | 决定 |
| --- | --- |
| 嵌套 module | 第一版不支持，直接报错 |
| 一个 module 跨多个文件 | 不允许；重复 module 报错 |
| 缺 module / 重复 module | 前端报错 |
| `provide *` | 本模块直接定义的全部全局名，包括 raw 内部 label |
| `provide` re-export | 允许：可以 provide 一个 require 进来的名字 |
| 重复 provide 同一个外部名 | 指向同一个完整名则幂等；指向不同完整名报错 |
| `rename-in` / `rename-out` | 只收一个 pair 列表：`(rename-in m ((external local) ...))`、`(rename-out ((local external) ...))` |
| `rename-in` 语义 | 导入目标的全部导出，只改列出的外部名 |
| `prefix-in` | 前缀是链头：`(f)` 变成 `(p f)`，不是字符串拼接 |
| 同一个 local 从两个 global 导入 | 报错 |
| import 与本模块定义同名 | 报错 |
| 循环 `require` | 允许；没有 base 的环在收敛后报未定义/未导出 |

## raw 的名字位置

- `(label chain ...)`：每个 chain 都是定义。
- 控制转移目标按 native 顺序：
  - 分支 / `j` / `call` / `tail`：第一个操作数；
  - `jal`：第二个操作数；
  - `c.beqz` / `c.bnez`：第二个操作数。
- 其它 raw 指令原样保留。`la` 等地址操作数等 data/地址模型定下来再加。

raw 目标用和 func 相同的模块环境解析：可以是本模块 label，也可以是 require 进来的
label。跨 unit 的分支是否合法属于 raw / layout 的检查，不在前端发明规则。

## 测试

```bash
cd riscv/riscv-core
racket test/frontend-test.rkt
# 或
raco test test/frontend-test.rkt
```
