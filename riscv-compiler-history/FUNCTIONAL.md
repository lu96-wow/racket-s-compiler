> **目标修正**：heap policy 现在是主目标，不是可选项；
> stack policy 只是 bootstrap。见 `FASM.md`。

# 函数式视角：寄存器分配与上下文切换

> 本文不是要把编译器改写成 Scheme，而是换一套**运行时模型**。
> 结论先说：C 里的“寄存器不够 → spill 到栈”和“调用 → 保存上下文”，
> 在函数式模型里分别变成“缓存驱逐”和“捕获续延闭包”。
> 两件事都不需要固定的 save/restore 集合，也不需要一个单独的 spill 阶段。

---

## 0. 先把两个问题重新命名

| C 模型 | 函数式模型 |
| --- | --- |
| 寄存器是“家”，栈是后备 | 环境帧（frame）是“家”，寄存器是缓存 |
| 一个值要么在寄存器，要么在栈槽 | 一个值**永远**在环境帧里；寄存器只是一份副本 |
| 分不到颜色 → spill 到栈槽 | 缓存行被驱逐 → 回落到它本来就在的 frame slot |
| 调用 → 按 ABI 保存 caller/callee-saved | 调用 → 换一个环境指针，或捕获一个续延闭包 |
| 上下文 = 栈 + 一组固定寄存器 | 上下文 = 帧链指针 + 续延（都是普通值） |
| 保存集合由 ABI 固定 | 保存集合 = 活跃变量集合，由 liveness 精确给出 |

关键不是“用函数式语法写后端”，而是承认：

> **vreg 是值，不是位置；preg 是缓存，不是所有者；frame 是环境，不是栈。**

这三句话一旦成立，两个问题都换了形状。

---

## 1. 定律一：vreg 是值，不是位置

C 的寄存器分配之所以难，是因为一个寄存器同时承担三件事：

1. 存放一个值；
2. 是一个可被后续指令覆盖的物理位置；
3. 跨调用时是否存活取决于 ABI。

函数式的做法是把这三件事拆开：

- `vreg` 是**不可变值**的名字（最好 SSA，一次定义）。
- `preg` 只是这个值当前所在的一个**缓存槽**。
- 值的“真身”在环境帧里，随时可以再取。

于是“溢出”有了三种实现，而不再是唯一的“存栈”：

| 溢出方式 | 函数式解释 | 适用 |
| --- | --- | --- |
| 捕获到 frame slot | 把值放进环境（closure capture） | 通用 |
| 重新物化（rematerialize） | 值是一个 thunk，用时再算 | 常量、`addi x0 K`、纯表达式 |
| 共享 | 持久数据结构，多个名字指向同一个值 | 不可变数据 |

**前提**：vreg 必须是单赋值的（SSA 或至少每次赋值新名字）。
理由不只是“风格”：

- 非 SSA 的 interference graph 着色是 NP-hard。
- SSA 的 interference graph 是 **chordal**（Hack/Grund/Goos），
  用最大势序（MCS）贪心着色就是**多项式最优**的。
- 只有在“团大小 > k”时才会真正需要溢出，而且溢出位置是结构性的，
  不是启发式猜的。

所以“把 vreg 改成 SSA”不是为了好看，是把寄存器分配从
“NP-hard + 启发式”变成“结构问题 + 最优算法”。

---

## 2. 定律二：frame 是环境，不是栈

把现在 `FORMS.md` 里的五张表合成一张：

```text
spill slot      溢出值
local slot      取地址的局部变量
outgoing slot   调用参数
saved slot      callee-saved / ra
closure env     闭包捕获的自由变量
        ↓
     全部是：frame slot
```

一个 frame 就是：

```racket
(frame
  (link fp)                 ; 指向外层环境，depth 0 = 自己
  (slots
    (slot0 v)               ; 参数、局部、溢出、捕获，没有区别
    (slot1 v)
    ...))
```

访问统一写成：

```racket
(env-ref dst (heap depth index))
(env-set (heap depth index) src)
```

- `depth` 是 de Bruijn 式的词法距离：0 = 当前 frame，1 = 外层，2 = 再外层。
- `index` 是 frame 内的槽号。
- 这正是 `FORMS.md` 已经预留的 `(heap depth index)`。

### 2.1 溢出 = 捕获

```racket
;; 原来
(store-slot slot3 v)
(load-slot v4 slot3)

;; 函数式解释
(env-set (heap 0 3) v)      ; 把 v 捕获进当前环境
(env-ref v4 (heap 0 3))     ; 从环境投影出来
```

没有“spill 专用基础设施”。溢出槽就是环境槽。
闭包捕获、局部变量、调用参数、返回值、saved 寄存器，全都共用这套地址。

### 2.2 指针是什么

在这个模型里，指针只有四种，都是普通值：

| 指针 | 含义 | 是否可变 |
| --- | --- | --- |
| `fp`（环境指针） | 当前 frame 链的根 | 否，换帧 = 换指针 |
| 续延指针 | `{code, env}` 闭包 | 否 |
| 堆对象指针 | cons / string / vector / closure | 对象头不可变，内容用 box |
| 栈指针 `sp` | 当前栈帧的边界（stack policy 才需要） | 是，但只在 prologue/epilogue |

因为 frame 是不可变的、投影是纯的，所以：

- **没有别名分析问题**：两个指针指向同一个 frame，读到的值永远一样。
- **驱逐永远安全**：把寄存器里的值丢掉，再从 frame 读回来，语义完全相同。
- 需要可变状态时，显式放一个 `box`（`(box v)` / `(unbox b)`），
  别名问题被局部化到 box，而不是弥漫到整个寄存器分配。

C 的 spill 之所以要小心，是因为 store/load 之间可能有别的 store 改写同一个地址。
函数式的 spill 没有这个问题：**frame 槽在值的生命周期内不被改写**。

---

## 3. 定律三：preg 是缓存，不是所有者

把寄存器分配重新表述成**缓存替换**：

```text
cache  = 物理寄存器集合
line   = 一个 vreg
backing store = frame slot（每个 vreg 一个）
miss   = 用的时候不在寄存器里 → load
evict  = 需要寄存器但缓存满了 → 选一行写回（如果脏）
dirty  = 在本块内定义、还没写回 frame
```

这与 C 的图着色 + spill 循环相比：

| 图着色 + spill | 缓存模型 |
| --- | --- |
| 全局分配，冲突图 | 线性遍历，按 next-use 驱逐 |
| 分不到颜色 → 改图 → 重建 liveness → 再着色 | 一次遍历，驱逐即溢出 |
| spill 是“失败后的补救” | spill 是“缓存的正常行为” |
| 需要 caller/callee-saved 规则 | 不需要；值随时可从 frame 取回 |
| 正确性依赖别名/内存模型 | 正确性只依赖“frame 不可变” |

驱逐策略就是 Belady：**驱逐下次使用最远的那个值**。
在已知未来（一个 block 内）时，这是最优的。跨 block 时是启发式，
但结构仍然是线性的，不需要不动点。

### 3.1 一个已经跑起来的实验

`regalloc-cache.rkt` 是这个模型的 100 行实现：

- 每个 vreg 固定一个 `slotN`；
- 每个 block 开始时清空缓存（frame 是唯一真相）；
- use 前 `load-slot`，def 后标脏；
- 缓存满时按“最远下次使用”驱逐，脏行先 `store-slot`；
- block 尾把“脏且 live-out”的行写回；
- 写回必须插在 terminator 之前（否则跳转会跳过 store）。

测试 `test/cache-test.rkt` 用一个最小解释器分别执行原始 vreg asm 和
分配后的物理寄存器 asm，要求结果一致：

```text
40 个同时 live 的值，26 个寄存器 → 产生 load/store，结果一致
40 个值跨 block 存活，26 个寄存器 → 块尾写回、块首重载，结果一致
30 个同时 live 的值，4 个寄存器   → 结果一致
无压力程序                        → 不产生任何 load/store
```

这个实验故意用了“每个 vreg 一个槽 + 每块清缓存”的最保守版本；
生产版本只需要把“块尾全写回”换成“逐出时惰性写回”，
把“每块清缓存”换成“沿单前驱边保留”，算法形状不变。

---

## 4. 定律四：上下文切换 = 捕获续延

C 的调用约定在做什么？

1. 把参数放进固定寄存器；
2. 保存“调用后还要用”的寄存器（caller-saved 由调用者存，callee-saved 由被调用者存）；
3. 保存返回地址；
4. 跳转；
5. 返回时恢复。

函数式的调用在做什么？

```text
call f(x) with continuation k
  = 把 x 和 k 交给 f
return v to k
  = 用 v 调用 k
tail call g(y) in k
  = 把 y 交给 g，k 原样传下去，不分配新帧
```

- **续延是一个闭包** `{code, env}`。
- `env` 里放的就是“调用之后还要用的值”= **live set**。
- 所以“保存哪些寄存器”不再由 ABI 固定，而是由 liveness 精确决定。
- 尾调用不分配续延，直接复用当前帧，递归就是循环。

### 4.1 `ra` 只是续延的缓存行

不需要把 `ra` 特殊化：

- 普通非尾调用：`ra` 是当前 one-shot 续延的快速缓存。
- 嵌套调用要覆盖 `ra`：把 `ra` 当作缓存行驱逐到续延帧，
  这正好就是“保存返回地址”。
- `call/cc`：把续延从缓存里**具体化**成一个一等值。
- 异常 / `dynamic-wind` / 线程：都是“调用某个续延”，不是新机制。

于是 `safepoint`、`roots`、`continuation`、`exception`、`thread`
共享同一个表示：

```racket
(cont K0
  (code Lafter)
  (env fp))          ; fp 指向一个 frame，frame 里是 live set
```

### 4.2 不再需要 caller-saved / callee-saved

因为：

- 调用者的值要么在**调用者的 frame** 里（被调者按词法作用域根本看不到），
- 要么在续延闭包的 `env` 里（被调者拿不到，除非显式传参），
- 要么在参数/返回寄存器里（ABI 明确约定）。

所以被调者**没有能力**破坏调用者的上下文。
“保存/恢复”退化成两件小事：

1. 换 `fp`（或 `sp`）；
2. 如果值只在寄存器里、又要跨调用，就存进续延帧（= 一次缓存写回）。

这不是“省掉保存”，而是把保存集合从“ABI 规定的固定集合”
缩小到“liveness 算出的精确集合”。通常小得多。

### 4.3 一个更强的说法

在 CPS 里，`f : A -> B` 就是：

```text
f : A × (B -> R) -> R
```

续延的**自由变量集合**就是活变量集合。
所以：

> **ABI 不是手写的，而是续延闭包的布局；liveness 就是 ABI。**

如果续延是 one-shot，它可以分配在栈上（或直接放寄存器）；
如果可能 multi-shot，就必须是持久 frame（堆或写时复制）。
这给出了 `call/cc` 与普通调用的统一实现，也给出了“什么时候必须堆分配”的判据。

### 4.4 三种 policy，同一套 form

`FORMS.md` 里的 `(policy (frame stack|heap) ...)` 正好可以承载三种 lowering：

| policy | frame 分配 | 上下文保存 | 适用 |
| --- | --- | --- | --- |
| `stack` | `sp` 调整 | 只有 `sp` / `ra`；值在栈帧 | C 互操作、无逃逸 |
| `heap` | `alloc-frame` | 无；换 `fp`，旧帧由 GC 决定 | 闭包、尾调用、call/cc |
| `hybrid` | 逃逸分析决定 | 非逃逸帧走栈，逃逸帧走堆 | 实用默认 |

三种 policy 共用同一张 `frame` 表、同一套 `(heap depth index)`、
同一套 `roots`。差别只在“frame 从哪来”和“什么时候释放”。

---

## 5. 结构性结论：什么时候还会“寄存器不够”

即使有 frame 兜底，寄存器压力仍然是真实成本。函数式模型给出的判断是：

1. **SSA 化之后，冲突图是 chordal 的。**
   着色多项式可解；只有团大于 k 时才必须溢出。
2. **溢出的位置是结构性的。**
   溢出 = 把一条 live range 的一段物化到 frame；
   在 SSA 下就是选一个支配边界/分叉点做 `env-set`。
3. **不可变让溢出“免费正确”。**
   不需要担心重排、别名、写后读；只需要担心性能。
4. **压力可以靠变换降低，而不只是靠 spill。**
   - 闭包转换方式（flat vs linked）会改变同时 live 的环境大小；
   - `let` 浮动 / 常量折叠 / 重物化减少长 live range；
   - 线性值（用一次）可以立刻释放寄存器，不产生冲突。

这也是为什么“先 SSA，再分配”比“先着色，再 spill”更函数式：
前者让问题有结构，后者是在和 NP-hard 搏斗。

---

## 6. 极端参考：环境机

如果把“preg 是缓存”推到极限，就得到 SECD / CEK / Krivine 这类环境机：

```text
值只在环境里；寄存器只缓存“当前表达式 / 当前环境 / 当前续延”。
```

在这种机器上：

- 没有传统意义的寄存器分配；
- 没有 spill；
- 上下文切换 = 换环境指针；
- 代价是每条指令都可能访存。

它不适合直接作为 RISC-V 后端，但它说明了一件事：

> **“寄存器不够”不是语言的本质问题，而是“把寄存器当作家”这个选择的后果。**

我们的目标不是环境机，而是“环境机 + 寄存器缓存 + 逃逸分析”：
语义上按环境机思考，性能上把热点值缓存进物理寄存器。

---

## 7. 映射到当前仓库

### 7.1 现有阶段

```text
asm(vreg)
  -> cfg
  -> branch-opt
  -> cfg
  -> liveness
  -> interference
  -> coloring            ; 当前：分不到就报错
  -> layout
```

### 7.2 函数式版本

```text
asm(vreg, SSA)
  -> cfg
  -> liveness
  -> frame-layout        ; 每个 vreg 一个 env slot（spill/local/arg/closure 同一张表）
  -> cache-alloc         ; preg 缓存 + 驱逐 + load/store
  -> call-lower          ; 非尾调用：捕获续延帧；尾调用：换 fp
  -> policy-lower        ; stack / heap / hybrid
  -> roots               ; safepoint 根 = fp 链 + 驻留寄存器
  -> layout
```

注意：

- `interference` / `coloring` 可以保留为 `cache-alloc` 的一个可选策略，
  两者不是互斥的；`cache-alloc` 负责“溢出”，图着色负责“全局选色”。
- `spill` 不再是一个“失败后重建”的循环，而是一次线性写回。
- `frame-layout` 把 `slot` 从“栈偏移”重定义为“环境索引”；
  stack policy 再把它具体化成 `sp + offset`。

### 7.3 form 层的变化

```racket
;; 环境帧：spill / local / arg / captured 没有区别
(frame
  (base fp)
  (link fp)                 ; 外层环境
  (slots
    (slot0 (kind arg))
    (slot1 (kind local))
    (slot2 (kind spill))
    (slot3 (kind captured))))

;; 环境访问（指令选择层）
(env-ref dst (heap 0 2))
(env-set (heap 0 2) src)

;; 续延（call-lower 层）
(cont K0 (code Lafter) (env fp))

;; 调用
(call f (args a0 a1) (cont K0))
(tailcall f (args a0 a1))
(return (a0))
```

`(heap depth index)` 就是 de Bruijn 索引：
`depth` 沿 `link` 走，`index` 是 frame 内槽号。
闭包捕获、溢出、参数、续延环境全都用它。

### 7.4 三张表其实是同一张

| 表 | 现在的含义 | 函数式含义 |
| --- | --- | --- |
| `slots` | spill / local / outgoing | frame 布局 |
| `frame` | 栈偏移 | 环境索引（stack policy 才变 offset） |
| `roots` | GC 根 | frame 里被引用的值 + 驻留寄存器 |
| `continuation env` | 无 | 调用点的 live set |

“spill 表 = frame 表 = GC 根表 = 续延环境表”，
这是整个模型能自洽的原因。任何一张表单独设计，都会重新长回 C 的复杂度。

---

## 8. 代价与取舍

必须诚实：

1. **堆帧 = 每次调用分配。**
   尾调用不分配；非尾调用分配一个 frame。生产实现靠逃逸分析
   把非逃逸帧放回栈上（hybrid policy）。
2. **GC 必须能看见 frame 链。**
   `fp` 是根；`roots` 表就是 frame 布局 + 驻留寄存器。
   这比“精确栈图”简单，因为 frame 是显式对象。
3. **multi-shot 续延需要持久帧。**
   不可变 frame 可以共享；可变局部变量放 box，捕获时共享 box。
   如果 frame 在栈上，multi-shot 捕获必须复制或禁止。
4. **外部 ABI 不能改。**
   调 C 函数时仍要遵守 SysV：caller-saved / callee-saved 变成
   “预着色约束 + 调用点 clobber 集”，由 cache-alloc 自动插入
   save/restore。也就是说：**C ABI 只是函数式 ABI 的一个特例**
   （续延是隐式的 `ra`，live set 被 ABI 放大成固定集合）。
5. **性能不是免费的。**
   cache-alloc 的 next-use 驱逐是启发式；跨块需要全局信息；
   图着色在非 SSA / 有预着色时仍然更强。
   实用做法是：**逻辑模型用 frame/续延，具体分配仍可用图着色**。

一句话：**语义上函数式，分配上工程化。**

---

## 9. 建议的实施顺序

1. **SSA 化 vreg**：每次赋值新名字；`copy` 用重命名消掉。
2. **引入 frame-layout**：每个 vreg 一个 `(heap 0 i)`；
   先把 `slot` 当“环境索引”，stack policy 再具体化。
3. **用 cache-alloc 替换 spill 循环**：
   先做“每个 vreg 一个槽 + 驱逐写回”，跑通正确性；
   再做“惰性写回 / 跨块保留”。
4. **call-lower**：
   先实现 one-shot 续延（`ra` 快速路径 + 溢出到续延帧）；
   非尾调用捕获 live set，尾调用换 `fp`。
5. **roots**：safepoint 处用同一张 frame 表生成根；
   寄存器里的值作为“额外根”列出。
6. **最后加 stack policy**：逃逸分析 + `sp` 调整，
   作为 heap policy 的优化，而不是另一套语义。
7. **`call/cc` 最后做**：它是“把续延从缓存具体化”，
   前面几步已经把它需要的表示建好了。

---

## 10. 一句话

> C 的寄存器分配在问“这个值放哪个寄存器、放不下放哪个栈槽”；
> 函数式的寄存器分配在问“这个值在环境里的哪个位置、寄存器只是它现在的缓存”。
>
> C 的上下文切换在问“这次调用要保存哪些固定寄存器”；
> 函数式的上下文切换在问“这个续延闭包捕获了哪些活变量”。
>
> 前者是**位置管理**，后者是**值管理**。
> 一旦 vreg 是值、frame 是环境、续延是一等值，
> spill 和 save/restore 就都变成了同一件事：**捕获**。

---

## 附：与现有文档的关系

- `SKELETON.md`：阶段 = 纯函数 + 替换表。本文不改变这一点；
  只是把 `slot`/`frame`/`roots` 三张替换表统一成环境表。
- `FORMS.md`：`(heap depth index)`、`(capture-context ...)`、
  `(policy (frame heap) ...)` 已经是为这个模型预留的接口。
- `DESIGN.md`：当前“无 spill、无栈帧、无调用约定”的最小链，
  可以作为 `stack` policy 的一个特例保留；函数式模型是它的推广。
- `regalloc-cache.rkt` + `test/cache-test.rkt`：本文第 3 节的可运行实验。

---

## 11. 当前实现状态（stack policy）

这一节记录已经落地的部分，避免文档和代码脱节。

### 11.1 文件

| 文件 | 作用 |
| --- | --- |
| `frame.rkt` | `frame / slot / heap / env-ref / env-set / cont / call / tailcall / return` 的形式、访问器、布局 |
| `lower-frame.rkt` | 抽取 `frame`/`cont`；`env-ref`/`env-set` -> `ld`/`sd`；插入 prologue |
| `call-lower.rkt` | 参数并行移动；`call`/`tailcall`/`return` -> `jal`/`jalr` + epilogue |
| `compile-asm.rkt` | 自动分派纯 asm 路径和 frame 路径 |
| `examples/frame-asm.sexpr` | 可运行的 frame 示例 |
| `test/frame-test.rkt` | 形式、布局、lowering、递归调用、并行移动、错误路径 |

### 11.2 已支持

```racket
(frame (base fp) (link fp)
  (slots (slot0 (kind arg))
         (slot1 (kind local))
         (slot2 (kind spill))
         (slot3 (kind captured))))

(env-ref dst (heap 0 i))
(env-set (heap 0 i) src)

(cont K0 (code Lafter) (env fp))
(call f (args a0 a1) (cont K0))
(tailcall f (args a0 a1))
(return (a0))
```

- frame 布局：`0 = old fp`、`8 = ra`、`16 + 8*i = slot i`、
  slot 区之后是 `s0..s11`。
- frame size = `align16(16 + 8*slot-count + 96)`。
- prologue 保存 `fp`、`ra`、`s0..s11`；epilogue 反向恢复。
- `call` 的参数做并行移动（用 `tp` 打破环）；间接目标冲突时先搬到 `gp`。
- `depth 0` 的环境访问是 `fp + offset`。
- one-shot 续延：`ra` = code，`fp` = env。
  `call` 之后用 `(jal x0 Lafter)` 回到续延；如果 `Lafter` 紧跟其后，
  branch-opt 会删掉这条跳转。
- 递归调用已验证：每次调用分配/释放自己的 frame。
- 跨调用的值会被调用点的 caller-saved 隐式 def 逼到 `s*`。

### 11.3 暂不支持

- `(heap depth i)` 的 `depth > 0`：需要词法 link（closure env），
  现在直接报错。现在的 offset 0 是**动态** old-fp，不是词法父环境。
- heap 续延 / multi-shot `call/cc`：现在是 stack policy + one-shot。
- 一个 asm 里的多函数：prologue 只插在第一个 label 之后；
  其他 label 共享同一张 frame。真正的多函数需要每个函数自己的 frame。
- frame 路径里的裸 `(jalr x0 ra 0)` 不会走 epilogue；
  应该写 `(return ...)`。示例里的 callee 故意不用 frame，所以是例外。
- 参数/返回值 > 8 个。
- callee-saved 精确集合：现在固定保存 `s0..s11`，以后可以缩成实际使用集合。

### 11.4 下一步

1. 把 `(heap 1 i)` 的 `link` 改成词法 link（闭包环境），
   同时保持 `0` 为动态 old-fp，或拆成两个字段。
2. 增加 `(policy (frame heap) ...)` 的第二种 call-lower：
   `call` 分配续延帧，`return` 调用续延，`tailcall` 只换 `fp`。
3. callee-saved 集合按实际使用裁剪。
4. 多函数 / 每个函数自己的 `(frame ...)` 与 prologue。
5. 把 `regalloc-cache.rkt` 的驱逐策略接进 frame 路径，
   替换“图着色失败就报错”。
