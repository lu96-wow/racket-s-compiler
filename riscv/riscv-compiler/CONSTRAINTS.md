# 设计约束：尺寸、布局与寄存器策略

> 记录“哪些 pass 可以改尺寸、什么时候可以改、scratch 为什么不能反过来触发 relax”。
> 当前代码不需要为此改动；这是对后续寄存器分配、spill、la 远形式、scratch-fill 的约束。

## 1. 三类决策

| 决策 | 依赖 offset | 改尺寸 | 放置位置 |
| --- | --- | --- | --- |
| 变量 spill / restore / regalloc 插代码 | 否 | 是 | `relax` 之前 |
| 分支 / 跳转 / la 远形式选择 | 是 | 是 | `relax` 固定点内 |
| scratch 填操作数 | 否 | **否** | `relax` 之后 |

核心原则：

> **只有依赖 offset 的尺寸变化，才进入 relax 固定点。**  
> **不依赖 offset 的尺寸变化，在 relax 之前完成。**  
> **尺寸不变的操作数填充，在 relax 之后完成。**

---

## 2. 强制规则

1. **relax 只做 offset 相关的形式选择**
   - 输入：当前 measured-layout 的 `needs-far` / `la-too-far`。
   - 输出：更大的、尺寸已知的 item。
   - 不插入 spill/restore，不做寄存器分配。

2. **尺寸单调增长**
   - 只允许从小形式升到大形式。
   - 如果某个决策理论上能缩小，**填 nop 保持原尺寸**，不要缩短。
   - 这样 relax 的“太远集合单调递增、必然收敛”仍然成立。

3. **scratch 不能改变尺寸**
   - `branch-indirect` = 12 字节，`jump-far` = 8 字节，缺的只是操作数。
   - scratch-fill 只允许把 hole 换成一个**已预留的 scratch 寄存器**。
   - 不允许在 scratch-fill 里 spill、插 load/store、加 label。

4. **会改尺寸的寄存器分配必须在 relax 之前**
   - 变量缓存溢出、spill/restore、调用前后保存，都属于这一类。
   - 它们不依赖 offset，所以不需要进入 relax 固定点。
   - 完成后，普通指令尺寸固定，再进入 relax。

5. **reserved scratch**
   - 每个 function / region 预留 1–2 个 scratch 寄存器，普通值分配不使用它们。
   - far 形式按顺序展开，同一时刻通常只需要一个 scratch。
   - 如果预留池不够，应在 relax 之前报错，而不是在 relax 之后插代码补救。

6. **不要在 relax 之后重新引入尺寸变化**
   - relax 收敛后，只允许 `scratch-fill`（尺寸不变）、`bind-labels`、`encode`。
   - `encode` 的 `(offset k item)` / `(size n)` 断言是最后的安全网。

7. **la 远形式**
   - 如果 la 远形式会改尺寸，并且依赖距离，就放进 relax 固定点。
   - 如果它需要 scratch，只能使用 reserved scratch。
   - 不要把它放到 relax 之后的 scratch-fill 里做尺寸变化。

8. **未知尺寸必须显式表示**
   - 不能依赖 `layout/forms.rkt` 的 `[else 4]` 兜底。
   - 兜底 4 字节是给“不透明代码”的设计，不是给“未来会变尺寸的 form”。
   - 真正未知尺寸的 item 必须有显式的大小契约或进入 relax 固定点。

---

## 3. 当前代码的状态

当前实现已经满足这些约束：

- `relax` 只消费 `needs-far`，升成固定尺寸的 `branch-far` / `branch-indirect` / `jump-far`。
- `branch-indirect` / `jump-far` 的 scratch 是“缺一个操作数”的 hole，尺寸固定。
- 当前没有 scratch-fill，也没有 regalloc/spill；`encode` 遇到未解决的 request 会拒绝。
- `layout` / `relax` 产 measured-layout；`bind-labels` 只绑定地址，不改尺寸。

所以现在：

> **代码不需要改，这是后续实现的约束。**

---

## 4. 推荐的流水线

```text
frontend / lower
  → expand-pseudo
  → analyze
  → dce
  → regalloc / spill        ; 尺寸可变，不依赖 offset
  → relax                   ; 尺寸可变，依赖 offset；只用 reserved scratch
  → scratch-fill            ; 尺寸不变，只填操作数
  → bind-labels
  → encode
```

对应检查：

| 阶段 | 允许改尺寸 | 允许改 label | scratch |
| --- | --- | --- | --- |
| regalloc / spill | 是 | 可以（在 layout 前） | 预留 |
| relax | 是 | 否（不造 label） | 只产生固定尺寸 hole |
| scratch-fill | **否** | **否** | 填 reserved register |
| bind-labels | 否 | 否 | 不关心 |
| encode | 否 | 否 | 不关心 |

---

## 5. 新 pass 的自检清单

加一个 pass 时先回答：

1. 它依赖 offset 吗？
   - 是 → 可能属于 relax 固定点。
   - 否 → 放在 relax 之前或之后。
2. 它会改尺寸吗？
   - 是 → 不能在 relax 之后；要么在 relax 之前，要么进入 relax。
3. 它会加/删 label 吗？
   - 是 → 必须在 layout 之前；不能放在 relax 之后。
4. 它需要 scratch 吗？
   - 是 → 用 reserved scratch；不要临时 spill 普通值。
5. 它能在 `encode` 的 offset/size 断言下通过吗？
   - 不能 → 说明尺寸契约被破坏。

---

## 6. 为什么不做联合固定点

理论上可以把 relax 和 scratch/spill 放进同一个循环：

```text
layout -> relax -> scratch/spill -> layout -> ...
```

但不推荐：

- scratch/spill 决策会随代码增长变化，可能反复；
- 单调增长只能保证不缩，不能保证不浪费；
- 收敛上界不再是“每条 item 最多升几档”；
- 逻辑会从 relax 泄漏到寄存器分配。

所以采用分段模型：

> **regalloc/spill 在前，relax 在中，scratch-fill 在后。**
