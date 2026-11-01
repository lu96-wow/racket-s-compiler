# amd64-help 设计

> `amd64-help` 是“把意图展开成规范指令 form”的策略层。
> 它不编码字节、不做布局、不绑 label，也不依赖 `compiler` 或
> `loko-compatibility`。指令事实与编码约束在 `../amd64-asm/`。

## 1. 设计来源

RISC-V help 层解决的是“ISA 基本指令装不下一个高层操作”：

- `li`：一个大常量要拆成多条指令；
- `la`：地址要拆成 PC 相对/绝对形式；
- `branch/jump`：远跳要拆成多条指令；
- 每种形式有明确范围和 size。

x86 的基本指令更强，但同样存在“策略不属于单条编码”的问题：

- `li`：`mov r32,imm32` / `mov r/m64,imm32` / `movabs r64,imm64` 的精确选择；
- `la`：RIP-relative `lea` vs 绝对地址 vs far 形式；
- `jmp/jcc/call`：short/near/far/trampoline 形式选择；
- `scratch`：far/trampoline 需要临时寄存器；
- condition code 别名：`z/nz/c/nc` 等只在展开层规范化；
- range 判断：每层不应各写一份 `(expt 2 31)`。

这些都属于帮助层，而不是 `amd64-asm` 的编码机制。

## 2. 目标模块

```text
amd64-help/
  main.rkt      稳定公共 API
  ranges.rkt    纯数值范围判断
  scratch.rkt   scratch 寄存器规则
  cc.rkt        条件码规范名 / 别名
  li.rkt        常量装载策略 + li-size
  la.rkt        地址装载策略（RIP-relative / absolute / future far）
  branch.rkt    条件分支形式选择 + 反转 + 范围
  jump.rkt      直接/间接跳转、调用、far/trampoline 预留
```

### 2.1 `main.rkt`

唯一稳定对外入口。叶子函数、临时 form 和内部 helper 不从这里导出。
`compiler/expand-pseudo` 只消费 `main.rkt`，不再直接知道具体 form 拼写。

### 2.2 `ranges.rkt`

`amd64-help/ranges.rkt` 是 help 层视图；规范实现对 `amd64-asm/ranges.rkt`，
这样 plan/encode 和展开策略使用同一组范围谓词。这里只导出纯整数谓词：

```text
fits-s8? fits-s16? fits-s32? fits-u8? fits-u32?
fits-rel8? fits-rel32? fits-disp32?
fits-width?
```

可选增加：

```text
fits-simm8?       ; -128..127
fits-imm32?       ; 指令编码允许的 32 位模式
fits-uimm32?
fits-imm64?
```

### 2.3 `li.rkt`

`li` 的输入是目标寄存器 + 常量/地址表达式，输出是规范 form 列表/plan，
并同时提供 `li-size`。选择规则必须只有一份：

| 值 | form | 字节 |
| --- | --- | --- |
| `-2^31 .. 2^31-1` | `mov r/m64, imm32`（符号扩展） | 7 (reg) |
| `0 .. 2^32-1` | `mov r32, imm32`（零扩展） | 5 |
| 其它 64 位 | `movabs r64, imm64` | 10 |
| 地址表达式 | `lea r64, [rip+disp32]` | 7 |
| 强制宽度 | `(imm8 ...)` / `(imm32 ...)` / `(imm64 ...)` | 由 form 决定 |

要求：

- 选择函数返回值必须已经带固定 immediate wrapper，不能把宽度选择留给编码器；
- `li-size` 与 `li` 调用同一个选择函数；
- 超过 RIP-relative disp32 的地址不在 `li` 里猜 far，而是交给 `la`/layout 报错或后续 far 策略；
- 不直接 require `compiler/layout`。

### 2.4 `la.rkt`

地址装载是独立策略：

```text
la-pcrel   -> lea rd, [rip+disp32]        ; 近
la-abs     -> li rd, absolute             ; 已知绝对地址
la-indirect-> mov rd, [abs]               ; 未来/显式
la-frame   -> lea rd, [base+disp]         ; 栈帧辅助
```

`li` 可以复用 `la` 的 RIP-relative 分支，但 `la` 不应该偷偷改 `li` 的常量策略。
近/远判断只返回 form 和范围信息，不解析 label。

### 2.5 `cc.rkt` + `branch.rkt`

`cc.rkt`：

- 规范条件码：`o no b ae e ne be a s ns p np l ge le g`；
- 别名：`z -> e`、`nz -> ne`、`c -> b`、`nc -> ae` 等；
- 只做名字规范化，不判断分支距离。

`branch.rkt`：

```text
jmp-short / jmp-near / jmp-indirect
jcc-short / jcc-near
branch-inverse
branch-range / jump-range
```

规则：

- short/near 是展开层显式选择的 form，不是 encoder 临时决定；
- `relax` 只消费 `jcc-short`/`jmp-short` 的 `needs-near` request；
- long branch 只负责“反条件 + 跳转序列”的形状，不负责 scratch 填充；
- 不解析 label，只返回带链 target 的 form。

### 2.6 `jump.rkt`

```text
call-near / call-indirect
jmp-near / jmp-indirect
jmp-far 预留
call-far 预留
```

far/trampoline 需要 scratch 时，`scratch.rkt` 负责：

- scratch 不能是目标/返回寄存器之外被隐式破坏的寄存器；
- 多个 scratch 必须互不相同；
- 没有 scratch 必须报错，不能生成半成品；
- 不把 scratch 泄漏给调用者之外。

### 2.7 `expand-pseudo` 的关系

`compiler/expand-pseudo` 只做“遍历 + 调用 help 的公共 API”：

```text
(li rd value)      -> help:li
(jmp target)       -> help:jump
(je target)        -> help:cc + help:branch
(call target)      -> help:jump/call
```

不再把 `li` 规则、条件码表、分支 form 选择复制到 `compiler`。

## 3. 依赖方向

```text
amd64-asm (facts / form / plan / encode)
      ^
      |
amd64-help (expansion policy / ranges / scratch)
      ^
      |
compiler (pipeline / layout / relax / bind / encode driver)

loko-compatibility  ----optional---->  compiler + amd64-help
amd64-elf           ----optional---->  build + symbols + image plan
```

`amd64-help` 只能依赖 `amd64-asm` 的共享形状/事实，不能依赖：

- `compiler/layout` / `compiler/encode` / `compiler/flow`
- `amd64-elf`
- `loko-compatibility`

## 4. size 与 form 的不变量

1. `li` 和 `li-size` 走同一个选择函数。
2. branch/jump 的 size 由选择的 form 决定，不由编码器猜。
3. 所有 symbolic immediate/displacement 在 help 层决定宽度或明确报错。
4. help 返回的 form 必须已经是 `amd64-asm` 能直接 plan 的规范 form。
5. help 不生成 label，不做地址绑定，不做 relax。
6. 新增 form 时同时更新：范围判断、选择函数、size、测试、本文件。

## 5. 当前实现与迁移

当前已经拆出的部分：

```text
ranges.rkt   纯范围谓词
cc.rkt       条件码规范名/别名
branch.rkt   jmp/jcc 显式 form + 反转
jump.rkt     call/indirect/far 占位
la.rkt       pcrel/frame/abs 地址 form
scratch.rkt  scratch 参数规范化与校验
li.rkt       li->form + li-size
main.rkt     稳定公共 API
test.rkt     叶子函数/API 测试
```

`compiler/expand-pseudo` 已经只 require `amd64-help/main.rkt`，不再自己维护
条件码表或分支 form 选择。

后续迁移：

1. `li.rkt`：把整数选择进一步改成显式 `(imm8/imm32/imm64 ...)` 或 form plan，
   让 immediate 宽度完全不依赖编码器的值判断；
2. `jump.rkt` / `scratch.rkt`：接入真正的 far/trampoline 序列；
3. `la.rkt`：增加 absolute/GOT 等显式策略；
4. 测试继续按叶子函数 + 公共 API 分层，和 `riscv-help/test/` 一样。

## 6. 边界

`amd64-help` 不做：

- 字节编码；
- 布局/段/地址绑定；
- label 解析；
- branch relaxation；
- 寄存器分配；
- ABI/调用约定；
- ELF/loader。
