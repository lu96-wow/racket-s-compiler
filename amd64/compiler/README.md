# compiler

## 作用

S-expression 汇编编译器：从 rich data / program items 走到每段字节。

## 流水线

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

Loko/ELF 是可选扩展：

```text
loko-source -> loko-compat -> program-items + data-items + loko-ir -> 后半段
             (loko-compatibility/flow.rkt 注册可选阶段)
```

`flow/core.rkt` 不依赖 `loko-compatibility` 或 `amd64-elf`。

## 目录

```text
compiler/
  item.rkt            程序/数据 item 共享形状
  expand-data/        rich 数据 -> 核心数据 item
  flatten/            module/provide/require 名字解析
  expand-pseudo/      伪指令 -> 真实 form
  analyze/            基本块 + flows
  dce/                死代码消除
  layout/             放置 + 度量 + anchors/requests/problems
  relax/              short -> near
  bind-labels/        anchors -> symbols + value 宽度检查
  encode/             bound-layout -> build
  flow/               stage 表 + 选择器
  test/               端到端测试
```

每层细节见对应 `DESIGN.md`；跨层规则见 [`../ARCHITECTURE.md`](../ARCHITECTURE.md)，
s-expression 形式见 [`../SEXP.md`](../SEXP.md)。

## 依赖

- `../amd64-asm/`：指令、寄存器、target 事实
- `../amd64-help/`：`li` / `la` / branch / jump 展开与范围判断
- `../loko-compatibility/`：**可选**前端，不在 core flow 依赖里

## 测试

```sh
racket amd64/compiler/expand-data/test.rkt
racket amd64/compiler/flatten/test.rkt
racket amd64/compiler/expand-pseudo/test.rkt
racket amd64/compiler/analyze/test.rkt
racket amd64/compiler/layout/test.rkt
racket amd64/compiler/relax/test.rkt
racket amd64/compiler/test/end-to-end.rkt
racket amd64/compiler/test/flow-test.rkt
```
