# amd64 S-expression 设计

> 本文定义 amd64 后端的 **s-expression 契约**、每一步的显式输入/输出，
> 以及处理逻辑的归属。用户写法见 [`SEXP.md`](SEXP.md)，
> 指令编码内部见 [`amd64-asm/DESIGN.md`](amd64-asm/DESIGN.md)。

## 1. 目标

1. **跨层数据一律是显式 s-expression**：有固定 head、固定字段、明确语义。
2. **每步只做一件事**：输入一种 IR，输出另一种 IR。
3. **操作显式**：构造、判定、取字段由 owner 模块提供，禁止在别处用
   `car/cadr/caddr` 猜结构。
4. **逻辑局部化**：一条规则只在一个模块里实现，不跨层复制。
5. **尺寸/形状稳定**：进入 layout 前，form、immediate 宽度、displacement
   宽度已经固定。

非目标：

- 让所有内部数据结构都变成 list；`mem`、`target`、`encoding-plan` 这类
  叶子事实可以继续用 struct。
- 让用户直接写机器码；用户仍然写 item / instruction s-expression。

## 2. S-expression 分层

```text
source form
  -> core item
  -> canonical program item
  -> program (blocks + flows)
  -> layout IR (measured / bound)
  -> build
```

每一层都有独立 head 和独立 owner。跨层时不传“任意 list”，只传该层允许的形状。

### 2.1 source form

用户/前端直接写的形状：

```scheme
(label 链)
(comment datum ...)
(align n)
(pad n)
(bytes b ...)
(fill n b)
(value width expr)
(reserve n)

(li rd 常量/地址)
(jmp target)
(jcc cc target)
(call target)
(je target)          ; 条件码别名
(mnemonic operand ...)
```

这一层允许伪指令、别名、未规范化的内存宽度。

### 2.2 core item

`expand-data` / `flatten` 之后的 item：

```scheme
(label 链)
(comment datum ...)
(align n)
(pad n)
(bytes b ...)
(fill n b)
(value width expr)
(reserve n)
```

owner：`compiler/item.rkt`。

### 2.3 canonical program item

`expand-pseudo` 之后，不再存在 `li` / `jmp` / `jcc` / `call` / 条件码别名：

```scheme
(label 链)
(comment datum ...)
(data item)
(jmp-short target)
(jmp-near target)
(jmp-indirect rm)
(jcc-short cc target)
(jcc-near cc target)
(call-near target)
(call-indirect rm)

(mnemonic operand ...)   ; 真实指令 form
```

owner：

- 数据/位置 item：`compiler/item.rkt`
- 指令 form：`amd64-asm/` 的 plan/table
- 条件码 / 分支选择：`amd64-help/`

### 2.4 program

当前实现用 `program` struct；目标契约是显式 s-expression：

```scheme
(program
  (block
    (head 链 ...)
    (item ...)
    ...)
  (flow
    (succ 块下标 ...)
    (fallthrough 块下标|#f)
    (root? #t|#f))
  ...)
```

owner：`compiler/analyze/program.rkt`（目标模块）。

约束：

- `block` 只包含 canonical program item。
- `flow` 只引用块下标，不引用地址。
- `program` 不包含指令字节、绝对地址、段信息。

### 2.5 layout IR

```scheme
(measured-layout
  (phase measured)
  (segments (segment ...) ...)
  (anchors (anchor 链 段名 偏移) ...)
  (requests (needs-near origin ...) ...)
  (problems (problem kind ...) ...))

(bound-layout
  (phase bound)
  (segments ...)
  (anchors ...)
  (symbols (symbol 链 段名 偏移 地址) ...)
  (requests ...)
  (problems ...))
```

owner：`compiler/layout/forms.rkt` + `compiler/bind-labels/`。

约束：

- measured 没有绝对地址。
- bound 的 symbol 是唯一地址来源。
- encode 只消费 bound，不重新算布局。

### 2.6 build

```scheme
(build
  (segment (name 名) (kind code|data|hole)
           (start 地址) (size n) (bytes #vu8(...)))
  ...)
```

owner：`compiler/encode/`。

## 3. 显式操作模型

每个 form 由 owner 模块提供四类操作：

```text
make-<kind>      构造规范形状
<kind>?          判定
<kind>-<field>   取字段
parse-<kind>     从外部/原始 shape 解析（必要时）
```

示例：

```racket
;; compiler/item.rkt
(make-label chain)
(label? x)
(label-chain x)

(make-value width expr)
(value? x)
(value-width x)
(value-payload x)

;; amd64-asm/memory.rkt
(parse-mem form)
(mem? x)
(mem-width x)
(mem-base x)

;; compiler/layout/forms.rkt
(make-segment name kind start end align)
(segment? x)
(segment-name x)
```

规则：

1. **owner 之外不 destructure**：不允许在 layout 里写 `(cadr (assq 'segments ...))`
   这种猜测；必须调用 accessor。
2. **构造必须规范**：`make-*` 负责字段顺序/默认值/合法性，调用方不手工拼 list。
3. **解析集中**：`parse-*` 只出现在输入边界；内部阶段不再 parse。
4. **错误信息带 owner 名**：例如 `parse-mem`、`make-value`，便于定位。
5. **可测试**：每个 `make-*` / `parse-*` 有 round-trip 或字段测试。

## 4. 每步显式分离

| step | 输入 | 输出 | 只做的操作 |
| --- | --- | --- | --- |
| `expand-data` | rich-data | data-items | 展开数据宽度/字符串/数组/地址字 |
| `flatten` | program-items + data-items | program-items + data-items + names | module/provide/require 名字解析 |
| `expand-pseudo` | program-items | program-items | 伪指令/条件码/分支 form 规范化 |
| `analyze` | program-items + data-items | program | 切块 + 构建 flow |
| `dce` | program | program | 删除不可达块 |
| `layout` | program + data-items + layout-spec | measured-layout | 放置 + 度量 + anchors/requests/problems |
| `relax` | program + data-items + layout-spec | measured-layout | short -> near 单调升级 |
| `bind-labels` | measured-layout | bound-layout | anchors -> symbols + 宽度检查 |
| `encode` | bound-layout | build | 解析符号/相对偏移 + 落字节 |

每一步的规则：

- 只读取自己声明需要的输入；
- 只写自己声明的输出；
- 不修改输入对象；
- 不调用下游阶段的内部函数；
- 不把下游数据塞进自己的输出。

## 5. 局部性规则

### 5.1 形状归属

| 形状 | owner |
| --- | --- |
| form/name/path/地址表达式 | `amd64-asm/shape.rkt` |
| 内存操作数 | `amd64-asm/memory.rkt` |
| 立即数 wrapper | `amd64-asm/operand.rkt` |
| 数据/位置 item | `compiler/item.rkt` |
| 指令 form / plan / bytes | `amd64-asm/` |
| 条件码/branch/jump 策略 | `amd64-help/` |
| segment/place/offset/anchor/request/problem | `compiler/layout/forms.rkt` |
| symbol / bound layout | `compiler/bind-labels/` |
| build segment | `compiler/encode/` |

### 5.2 禁止事项

- 禁止在 `layout` 里重新实现 `instruction-size`。
- 禁止在 `encode` 里重新选择 immediate/displacement 宽度。
- 禁止在 `expand-pseudo` 里复制条件码表或分支策略；调用 `amd64-help/main.rkt`。
- 禁止在 `loko-compatibility` 之外出现 Loko 写法。
- 禁止用 `car/cadr` 读取不属于本模块的 form；必须走 accessor。
- 禁止把“当前 target”“当前段”“当前地址”放进全局变量。

### 5.3 局部状态

- `layout` 的 cursor、anchors、problems 是函数内部状态。
- `relax` 的轮次和 edits 是函数内部状态。
- `flatten` 的模块/名字表是本次调用局部状态。
- `encode` 的段游标是本次调用局部状态。

## 6. 规范形式不变量

1. `expand-pseudo` 之后没有伪指令。
2. 所有 symbolic immediate / displacement 在 layout 前有固定宽度。
3. short/near 是 form，不是 encoder 临时选择。
4. `jmp-short` / `jcc-short` 只允许被 relax 升级为 near。
5. `li` / `la` 的 size 与展开使用同一个选择函数。
6. `instruction-size target` 与 `encode-instruction target` 使用同一个 plan。
7. measured layout 不含绝对地址。
8. bound layout 的 symbol 是 encode 唯一地址来源。
9. `hole` 段只含位置 item，不产生文件字节。
10. 任何不合法组合在所属阶段报错，不静默 fallback。

## 7. 当前实现与迁移顺序

已具备：

- `shape.rkt` / `memory.rkt` / `operand.rkt`；
- `compiler/item.rkt` 的 `make-label` / `make-comment` / `make-align` /
  `make-pad` / `make-bytes-item` / `make-fill` / `make-value` /
  `make-reserve` 构造函数；
- `expand-data` 和 `layout` 的产物开始使用 item 构造函数；
- `layout/forms.rkt` 已提供 `segment` / `offset` / `anchor` /
  `request` / `problem` / `measured-layout` / `bound-layout` 的构造与 accessor；
- `layout` / `relax` / `bind-labels` / `encode` 已使用这些 accessor；
- `bind-labels/forms.rkt` 提供 symbol 的显式构造与 accessor；
- `amd64-asm` 的 explicit plan / encoding-plan；
- measured/bound/build 已经是显式 s-expression；
- `amd64-help/main.rkt` 收敛条件码、li、branch、call 策略。

需要迁移：

1. `compiler/item.rkt` 构造函数已加入；继续清理 `loko-compatibility` 等
   生产者的裸 list 构造。
2. `program` / `block` / `flow` 从 struct 迁成显式 s-expression，或明确保留为
   唯一允许的 struct IR；不能两种风格混用。
3. layout IR 的 segment/offset/anchor/request/problem/measured/bound
   已 accessor 化；继续把 `place` 收进 owner。
4. `encode` 改用 layout accessor，不再直接 `assq/cadr`。
5. 增加“owner 外不得 destructure”的审计：至少对新增代码做 grep 检查。
6. 文档与测试同步更新。
