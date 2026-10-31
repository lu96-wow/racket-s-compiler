# amd64 后端

这是与 `riscv/riscv-compiler` 分离的 amd64 后端。目标是把 s-expression 程序/数据
经过固定流水线变成每段字节。

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | 分层、依赖规则、不变量、错误模型 |
| [`SEXP.md`](SEXP.md) | 程序/数据/内存/控制转移的 s-expression 形式 |
| [`PLAN.md`](PLAN.md) | 目标、阶段计划和进度 |
| [`loko-compat/DESIGN.md`](loko-compat/DESIGN.md) | Loko 旧汇编写法到核心 item 的纯变换 |
| `*/DESIGN.md` | 每层的职责、输入输出、边界 |

## 当前流水线

```text
rich data
  -> expand-data
  -> flatten
  -> expand-pseudo
  -> analyze
  -> dce
  -> relax          ; 内部反复驱动 layout
  -> bind-labels
  -> encode
```

`layout` 可以单独选择，默认流通过 `relax` 间接使用它。

Loko 兼容入口是另一条纯前端：

```text
loko-source (text/data)
  -> loko-compat
  -> program-items + data-items
  -> expand-pseudo -> analyze -> ...
```

它只做写法变换；`%section` / `%comm` / `%origin` / `%mode` / `%call` 属于
image 层，当前显式报问题。

## 目录

```text
amd64/
  sexp.rkt           共享 s-exp 形状 + 内存操作数
  item.rkt           程序/数据 item 共享形状
  insn.rkt           真实指令表 + instruction-size + encode-instruction
  registers.rkt      寄存器事实
  target.rkt         目标事实 + 填充
  loko-compat/       Loko 旧汇编写法 -> 核心 item
  expand-data/
  flatten/
  expand-pseudo/
  analyze/
  dce/
  layout/
  relax/
  bind-labels/
  encode/
  flow/
  test/
```

`sexp.rkt` / `item.rkt` / `insn.rkt` / `registers.rkt` / `target.rkt` 是共享事实，
不属于某一层的策略。

## 当前状态

已实现：

- Loko 汇编写法兼容层（`loko-compat`）
- rich 数据展开、module/flatten 名字解析
- 伪指令规范化：`jmp/jcc/call/li`、条件码别名
- amd64 控制流分析、DCE
- 扁平 item 布局 + program blocks 桥接
- 精确 `instruction-size`
- `jmp-short/jcc-short -> near` 只增 relax
- anchor -> symbol 绑定
- bound layout -> 段字节
- 符号内存 displacement（固定 disp32，encode 时解析）
- 整数 `li` -> `mov`，地址表达式 `li` -> RIP-relative `lea`
- 基本整数/控制流/内存指令编码
- `comment` 零尺寸 item、`cmovcc`、`b128` 内存宽度事实

未实现：

- `place` region / 通配 / unplaced problem
- layout 消费 `flows` / `broken-fallthrough`
- `needs-far` / far form / trampoline / scratch 寄存器
- image 层：`%section` / `%comm` / `%origin` / `%mode` / `%call`
- 外部符号 / reloc / loader
- `imul` 三操作数、`shift by cl`、`adc/sbb`、SSE/AVX
- `li` 超出 RIP-relative ±2GiB 的地址

## 测试

```sh
racket amd64/loko-compat/test.rkt
racket amd64/encode/test.rkt
racket amd64/expand-pseudo/test.rkt
racket amd64/expand-data/test.rkt
racket amd64/flatten/test.rkt
racket amd64/layout/test.rkt
racket amd64/analyze/test.rkt
racket amd64/relax/test.rkt
racket amd64/test/end-to-end.rkt
racket amd64/test/flow-test.rkt
```
