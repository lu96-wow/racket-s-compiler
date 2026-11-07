# bind-labels（`bind.rkt`）

## 作用

把 measured-layout 的 `anchors` 落到绝对地址，产出 bound-layout。

核心公式：

```racket
绝对地址 = segment.start + anchor.offset
```

## 相关 s-exp

输入 measured-layout：

```racket
((phase measured)
 (origin 镜像基址)              ; spec 的 (origin …)，缺省 0
 (segments …)
 (anchors (anchor 链 段名 偏移) …)
 (requests …)
 (problems …))
```

输出 bound-layout：

```racket
((phase bound)
 (origin 镜像基址)
 (segments …)
 (anchors …)
 (symbols (symbol 链 段名 偏移 绝对地址) …)
 (link (base 镜像基址) (symbol 链 绝对地址) …)   ; 对外投影，见下节
 (provides 链 …)                                 ; 对外承诺哪些名字，见下节
 (requests …)
 (problems …))
```

新增检查：

- `(value 宽度 值)` 的值是否放得进宽度
- `segment-overflow`

## 设计思路

- `layout`/`relax` 只该管“位置”；`offset → address` 是一个独立的收尾。
- 绝对地址只在 bound-layout 出现，`encode` 就不可能误用松弛中间值。
- `value` 宽度和段容量只有最终地址/最终尺寸才知道，所以放在这里。
- 幂等；不改 item / offset / size；不解决 requests。

## link 表：对外的“名字 → 绝对地址”

`symbols` 行是 `(symbol 链 段名 偏移 绝对地址)`，其中**段名 / 偏移是我自己的账**；
对外能承诺的只有“这个名字在哪个地址”。所以 `bind-labels` 同时产出一张投影表：

```racket
(link (base 镜像基址)          ; = spec 的 (origin …)，缺省 0
      (symbol 链 绝对地址) …)
```

三条性质，都是刻意的：

1. **两列**。段名/偏移不进 link 表：它们是我的内部结构，外部只关心“名字在哪”。
   需要段名/偏移的地方去读 `symbols`。
2. **只有已解析的行**。行只来自 `anchors`，所以输出里不可能出现 `#f` / 未解析项；
   输出可以直接当另一个镜像的输入用（缺口不随表传播）。
   未解析的外部符号是**输入侧**的概念，等做输入时再引入。
3. **按地址升序，同址按链的写法排序**。这样两份产物的 link 表可以逐字节比较
   （diff 稳定），也便于做重叠 / 漂移检查。

`base` 是这次布局用的镜像基址。绝对地址是“相对谁”的数：整体搬到别的地址时
所有地址加 `(新 base − base)`，所以没有 `base` 的地址只是一个裸数。
它取 spec 的 `(origin …)` 而不是 `min(段 start)` —— 后者在有 hole 段时会给出
没有意义的数（例如 bss 在 `0x80000000`、代码在 `0x1000`）。

`encode` 把它**原样搬进产物**（`(build (link …) (provides …) (segment …) …)`），不重算地址。

## provides 表：对外承诺哪些名字

跟 link 表是一对：link 说“所有名字在哪”，provides 说“其中哪些是对外的”。

```racket
(provides 链 …)        ; 只有链，地址在 link 表里，不存两份
```

- 来源是 `flatten` 记下的导出集合（各模块 `(provide …)` 的并集，用**绝对链**）；
- `exports = 'all` 表示**全单元没有 `(provide …)` 子句** → 平铺镜像语义，一切都导出；
- 顺序跟 link 表一致（按地址升序），所以“按 provides 过滤 link”是取子序列；
- 名字在 link 表里查不到 → `(provide-unknown 链)` problem（不抛异常）。

为什么记绝对链而不是 `provide` 里写的名字：flatten 之后**绝对链是唯一的名字身份**，
link 表也按它排。`rename-out` 的外部名只在本单元的 `require` 绑定里有意义；
跨单元怎么称呼它属于输入侧（等做输入时再定，届时可能要给 link 表加别名行）。

`link-file.rkt` 把这两张表合成**单独一个文件**（内容 = 按 provides 过滤的 link 表），
所以镜像文件和 link 文件可以分开交付。

## 未来（现在没做，先记着）

- **按 `(provide …)` 过滤**。源语言里已经有模块的 `provide` 了，但 `flatten`
  解析完就把模块结构扔掉（“之后的层看到的全是完整链”），所以现在 link 表是
  **全导出**。要做“只导出 provide 的”，得让 flatten 把导出集合传下来。
- **输入侧**（外部符号）：形状已经锁定成同一份 `(link (base …) (symbol 链 地址) …)`，
  输入额外允许 `(symbol 链 #f)` 表示未解析。两处 `base` 不一致必须报错。
- **漂移校验**：外部符号参与了距离决策（短跳）时，对方改了地址就会静默错。
  届时需要 `(extent …)` 或摘要来复查。

## 边界

不松弛、不填 scratch、不补跳、不重定位/链接。
`needs-far` / `scratch-hole` / `la-too-far` 原样保留，`encode` 要求 requests/problems 都空。

未来寄存器层应插在 `relax` 之后、`bind-labels` 之前；凡会改尺寸的 pass 也必须在它之前收敛。
