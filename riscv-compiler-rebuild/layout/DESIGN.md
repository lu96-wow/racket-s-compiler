# layout 布局计算（`layout/forms.rkt` `layout/layout.rkt`）

> 把"块 + 数据 + 段表"变成"每段的 item 序列 + 偏移 + 符号 + problems"。
> 只算，不选：不升级远形式、不填 scratch、不补跳、不重排。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 段内单游标累加尺寸 | 判断真指令是否合法（属于 encode） |
| `align` 补齐（按**绝对地址**） | 填 scratch 空槽（留给"寄存器使用"层） |
| 记符号（链 → 段 / 偏移 / 绝对地址） | 补 fallthrough 跳转 |
| 检查范围（`needs-far` / `value-out-of-range` / `la-too-far`） | 分支松弛（属于 relax） |
| 报放置问题（`unplaced` / `broken-fallthrough` …） | 改 item（除了给 relax 留定位） |

## 2. 输入 / 输出

```
program : dce 输出 ((blocks …) (flows …))
data    : 核心 item 列表（expand-data 输出）
layout  : ((segments (segment (name 名) (kind code|data)
                            (start x) (end y) (align n)) ...)
           (place 段名 链 ...) ...)
```

```racket
(layout-program program data layout-input)
  -> ((segments (segment (name s) (kind code) (start #x1000) (end #x1FFF) (align 4)
                          (items (offset 0 (label main))
                                 (offset 0 (lwu t0 sp 8))
                                 (offset 4 (bge t1 t0 (done)))
                                 (offset 8 (label done))
                                 (offset 8 (add a0 a0 x0)))
                          (size 12)) ...)
      (symbols (symbol (main) s 0 #x1000) …)
      (problems …))
```

`kind` 只有 `code` / `data` 两种。代码里**没有 `section`**，也没有 `primary` / `entry`：
段归属只写在 `place` 行里。

同一个 `data` 列表也要喂给 analyze 的第二个参数（数据里的地址字 = 取过地址）。

## 3. API

| 文件 | API |
| --- | --- |
| `layout.rkt` | `layout-program` `layout-problems` `as-items` `run` |
| `forms.rkt` | `item-size` `item-kind` `form-range` `scratch-hole?`（`branch-form?` / `jump-form?` 直接借 `analyze/insn.rkt`，名单只有一份）；分类 `label-form?` `align-form?` `bytes-form?` `fill-form?` `value-form?` `compressed-form?` `branch-form?` `jump-form?` `control-form?` `control-target` `segment-form?` `segment-kind?`；取值 `value-width` `value-payload`；地址表达式 `ref-expr?` / `ref-chain` / `ref-addend` 来自 `sexp.rkt` `la-form?` `la-scratch` `jump-far-form?` `jump-far-link` `jump-far-scratch` |

## 4. 规则

### 4.1 本层的数据词汇只有五个

| item | 尺寸 | 说明 |
| --- | --- | --- |
| `label 链...` | 0 | 位置 |
| `bytes b...` | 元素个数 | 已定序字节 |
| `fill 字节数 b` | 重复次数 | 与端序无关 |
| `value 宽度 值` | 宽度 | 值是什么由 encode 解释 |
| `align n` | 由游标算 | **输入侧的请求**；度量时换算成 `(pad …)` |
| `pad n` | `n` | **精确插 n 个字节**；`align` 的换算结果就是它（源码也可以直接写） |

**其余 item 一律当成不透明代码**：4 字节（`c.*` 2 字节）。不查拼写、不查操作数 ——
那是编码层的事。所以 `item-size` / `item-kind` 的兜底 `4` / `'code` **是设计，不是漏检**。

### 4.2 放置

- **单位**：代码用 analyze 的块；数据用「label 游程」（数据没有控制流）。
- **`place` 行**：按**精确链**（`equal?`）匹配块头或游程的 label；不做前缀、不按 kind 自动落位。
- **region**：命中的块是锚点，之后直到下一个锚点的块跟随它。
- **顺序**：段内按源顺序（程序先、数据后）；`place` 行书写顺序无关。
- 指向块内位置标记的链 → `unmatched-place`（块不能拆）。

### 4.3 度量

段内一个游标从 `start` 起；`label` 不占字节只记偏移；其余按 `item-size` 累加。

`align` 在**这里**换算成等价的事实 `pad`（源码里也可以直接写 `pad`，那是"就插 n 字节"）：

```racket
(align 8)   →  (pad 补出来的字节数)      ; 取决于绝对地址
(pad 5)     →  (pad 5)                   ; 源码直接写: 与地址无关
```

`pad` 的两个用途（都归本层度量、encode 落字节）：

| 来源 | 语义 | 常见场合 |
| --- | --- | --- |
| `align` 换算 | 补到对齐 | 结构体字段、指令对齐 |
| 源码写 `pad` | 精确插 n 字节 | 固定大小的槽位、把段补到某个长度 |

填什么与地址无关，只由段的 `kind` 决定（`target.rkt`）：`code` → `nop` / `c.nop`，`data` → 0。

```racket
(align n)  ->  (pad (modulo (- n (modulo (+ start cursor) n)) n))
```

对齐依据是**绝对地址** `start + cursor`（段 start 不一定被 `n` 整除），不是段内偏移。
绝对地址公式只在这一处出现 —— 产物里直接写"要补几个字节"，encode 只需要决定填什么。

产物里 `(offset k item)` 记的是该 item **开始**的偏移，`align` 的 `(pad n)` 记在
补齐**前**的位置（下一条的偏移自然会 +n）。

### 4.4 尺寸表

| item | 字节 |
| --- | --- |
| `label` | 0 |
| `bytes` / `fill` | 元素个数 / 重复次数 |
| `value 宽度 值` | 宽度 |
| `align n` | 由游标算（度量时换算成 `(pad …)`） |
| `pad n` | `n` |
| `li` | **由常量精确决定**：`li-size` ∈ {4, 8, 12, 16, …, 32} |
| `la` | 8（近形式 `auipc+addi`） |
| `b*` / `jal` / `jalr` / 其他 | 4 |
| `c.*` | 2 |
| `branch-far` | 8 |
| `branch-indirect` | 12 |
| `jump-far` | 8 |

`li` 的尺寸不是上界：常量就在 item 里，`item-size` 直接问 `riscv-help` 的 `li-size`。

### 4.5 可达距离（区间，不是 ±幅度）

偏移都是偶数，所以正向最大是 `2^n - 2`：

| item | 区间 |
| --- | --- |
| `beq/bne/blt/bge/bltu/bgeu` | `[-4096, 4094]` |
| `c.beqz` / `c.bnez` | `[-256, 254]` |
| `c.j` / `c.jal` | `[-2048, 2046]` |
| `jal` | `[-1048576, 1048574]` |
| `branch-far` | `[-1048572, 1048578]`（`jal` 在 `+4`，区间整体右移） |
| `branch-indirect` / `jump-far` | 不设限 |

区间比幅度多挡一种情况：`d = +4096` 看起来够，其实编不出来。

### 4.6 远形式：寄存器全部显式

```racket
(branch-far      <cond> a b L)      ; 8B, 反向分支 + jal
(branch-indirect <cond> a b L)      ; 12B, 空槽
(branch-indirect s <cond> a b L)    ; 已填
(jump-far link L)                   ; 8B, link = 零寄存器时空槽
(jump-far link s L)                 ; 已填
;; <cond> ∈ beq bne blt bge bltu bgeu
```

- **没有 `call-far`**：它就是 `(jump-far ra L)`，两个名字等于两种拼写。
- **`<cond>` 必须写**：不带条件的形式展开不了。
- **scratch 有两种槽**：`branch-indirect` / `(jump-far x0 …)` 是**必填空槽**（缺了报
  `scratch-hole`，软问题，留给"寄存器使用"层）。源码里手写**带空槽**的远形式
  = 造了一个未完成的 item：layout 报 `scratch-hole`，encode 拒绝出产物 —— 这是诊断，不是静默错误；`la` 的 scratch 是**可选槽**
  （`(la rd 链)` / `(la rd tmp 链)`），缺省不是缺陷，不报 `scratch-hole`。

### 4.7 范围检查：只有 layout 有符号表

```racket
(value 宽度 (ref 链 加数))      ; 链存在? 地址 + 加数放得进 宽度 个字节?
(la rd [tmp] 链)                ; 链存在? delta 落得进 auipc+addi?
```

- `value` 的整数不用查（expand-data 已经按宽度查过值域）。
- `la` 用 `fits-auipc-pair?`（不是简单的 ±2GB 区间，而是 auipc+addi 的精确可达集）。
- 链不存在 → `undefined-target`；放不下 → `value-out-of-range` / `la-too-far`。
  这三者和 `needs-far` 一样是**范围**问题，不是指令合法性 —— 只有 layout 算得出地址。

### 4.8 problems：哪些是自己的，哪些是交接

| 类别 | problems |
| --- | --- |
| 放置 | `unplaced-block` `unplaced` `unlabeled-run` `ambiguous-placement` `unmatched-place` `unknown-segment` |
| 段 | `segment-overflow` `segment-misaligned` `segment-overlap` `segment-name-duplicated` `segment-bad-range` |
| 段归属 | `code-data-mixed` `data-code-mixed` |
| 顺序 | `broken-fallthrough` |
| 符号 / 范围 | `undefined-target` `value-out-of-range` `la-too-far` `needs-far` |
| 交给 relax | `needs-far`（升远形式）、`scratch-hole`（等"寄存器使用"层） |

`needs-far` / `scratch-hole` 带 `(code 块下标 项下标)` 定位（`measure` 记在 `measured.origins` 里），
relax 才能精确改那一条。

**不在这个名单里的都不是本层的事**：拼写、操作数个数、立即数范围、code 段对齐是否合法，
都是"变二进制"（encode）的事。

## 5. 不归本层管

- 合法性（拼写 / 操作数 / 立即数范围 / code 段对齐）：encode。
- 填 scratch 空槽：留给"动态内存布局 / 寄存器使用"层。
- 分支松弛：relax。补 fallthrough 跳转：目前没有实现。
- 端序：encode。

## 6. 测试（`layout/test.rkt`，177 条）

形式表（尺寸 / 类别 / 区间 / 空槽 / 值）、放置、region、对齐（含绝对地址）、
fallthrough、符号表、每类 problem、expand-data 边界（expand-data 的输出必须能被本层度量）、
`li` 精确尺寸、`la` 范围。

## 7. 已知缺口

- `place` 只能按精确链匹配，没有通配 / 正则。
- 段 `end` 只是容量上界（用来查 `segment-overflow`），不参与地址计算。
- 补 fallthrough 跳转没做（`broken-fallthrough` 只报）。
