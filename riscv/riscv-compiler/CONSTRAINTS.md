# 设计约束：尺寸、布局与形式选择

> 当前模型：**前端选择形式，后端只做布局度量 + 检查 + 编码**。
> 没有分支松弛，没有固定点，没有 requests。

## 1. 责任划分

| 决策 | 谁做 | 什么时候 |
| --- | --- | --- |
| 短/远分支、短/远跳转 | 前端 | 产生 item 时 |
| `la-pcrel` / `la-pcrel-li-add` | 前端 | 产生 item 时 |
| `li` 展开 | 前端/共享 `li-size` | 产生 item 时 |
| 指令顺序、段、对齐、label 位置 | `layout` | 一次线性度量 |
| 目标存在/范围/scratch 检查 | `check` | 布局之后 |
| 绝对地址、宽度/容量 | `bind-labels` | 检查之后 |
| 字节编码 | `encode` | 最后 |

核心原则：

> **尺寸在进入 `layout` 前就固定。`layout` 之后不允许改 item 尺寸。**
> **跳转够不够远是检查条件，不是后端选择形式的依据。**

---

## 2. 强制规则

1. **item 尺寸是形式的纯函数**
   - `beq` 4 字节；`branch-jal` 8；`branch-auipc-jalr` 12。
   - `j` / `jal` 4；`jump-auipc-jalr` 8。
   - `la-pcrel` 8；`la-pcrel-li-add` 固定上界（rv64 40）。
   - `li` 由常量精确决定；同一常量同一尺寸。

2. **前端必须显式选择形式**
   - 短形式超范围 -> `check` 报 `out-of-range`。
   - 近 `la-pcrel` 够不着 -> `check` 报 `la-too-far`。
   - scratch/base/tmp 是零寄存器 -> `check` 报 `zero-scratch`；tmp 和 rd 重合 -> `bad-scratch`。
   - 不自动升级，不自动缩回。

3. **`check` 不改尺寸、不改 item、不加 label**
   - 只追加 `problems`，`segments` / `anchors` 原样传下去。

4. **`bind-labels` / `encode` 是尺寸不变的收尾**
   - 不松弛、不填 scratch、不补跳。
   - `encode` 的 `(offset k item)` / `(size n)` 断言是最后的安全网。

5. **scratch 是显式操作数**
   - `branch-auipc-jalr` / `jump-auipc-jalr` / `la-pcrel-li-add` 需要哪个 scratch，由前端写。
   - 后端不维护 scratch 候选集，不做 liveness 选寄存器。

6. **会改尺寸的 pass 必须在 `layout` 之前**
   - spill / restore / regalloc 插代码、`li` 展开、形式选择都属于这一类。
   - `layout` 之后只允许尺寸不变的收尾。

7. **未知尺寸必须显式表示**
   - 不能依赖 `layout/forms.rkt` 的 `[else 4]` 兜底。
   - 兜底 4 字节是给“不透明代码”的设计，不是给“未来会变尺寸的 form”。

---

## 3. 当前流水线

```text
frontend / lower
  -> expand-struct          ; struct 布局 + 静态数据 + 字段访问展开
  -> expand-data
  -> flatten
  -> analyze
  -> dce
  -> layout              ; 位置 + 尺寸 + anchors；不选形式
  -> check               ; 显式形式检查；只报 problems
  -> bind-labels         ; 绝对地址 + 宽度/容量
  -> encode              ; 字节
```

对应检查：

| 阶段 | 允许改尺寸 | 允许改 label | scratch |
| --- | --- | --- | --- |
| frontend / lower | 是 | 是 | 前端显式写 |
| layout | 否 | 否 | 不关心 |
| check | 否 | 否 | 只检查缺失 |
| bind-labels | 否 | 否 | 不关心 |
| encode | 否 | 否 | 不关心 |

---

## 4. 新 pass 自检清单

加一个 pass 时先回答：

1. 它会改尺寸吗？
   - 会 → 必须在 `layout` 之前。
2. 它会加/删 label 吗？
   - 会 → 必须在 `layout` 之前。
3. 它依赖 offset 吗？
   - 是 → 只能放在 `layout` / `check` 里做**只读检查**，不能改形式。
4. 它需要 scratch 吗？
   - 是 → 由前端显式写；`check` 只检查是否缺失。
5. 它能在 `encode` 的 offset/size 断言下通过吗？
   - 不能 → 尺寸契约被破坏。

---

## 5. 为什么不做联合固定点

旧模型把“形式选择”和“布局”放在同一个循环里：

```text
layout -> needs-far -> 升形式 -> layout -> ...
```

新模型直接取消这个循环：

- 尺寸由前端固定，`layout` 一次线性度量；
- 范围不够是错误，不是重新布局的信号；
- 没有“尺寸变了但不产生新决策”的振荡；
- 没有 `needs-far` / `scratch-hole` 这类跨层请求。

代价是前端必须自己选择形式，并且代码可能比自动松弛更大；这是用可预测性换优化。
