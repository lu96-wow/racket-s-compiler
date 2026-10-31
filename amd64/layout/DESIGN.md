# amd64 layout（第一版）

> 扁平 item 布局：按 `place` 锚点切段，累加 item 尺寸，`align` 变成 `pad`，
> 记录 anchors 和 problems。还没有 CFG / blocks / relax。

## 输入

```racket
(layout-items items spec)
```

`spec`：

```scheme
'((segments
   (segment (name text) (kind code) (start #x200000) (end #x201000) (align 16))
   (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
  (place text (text))
  (place data (data)))
```

## 规则

- `place` 的链命中 `label` 时切换当前段；未命中当前段的 item 被忽略。
- `align n` 按**绝对地址** `start + cursor` 算成精确的 `(pad n)`。
- 代码 item 的尺寸来自共享的 `amd64/insn.rkt` 的 `instruction-size`；layout 不依赖 encode 层。
- 数据 item：`value` / `bytes` / `fill` / `pad`。
- 产物：

```scheme
((segments (segment ... (items (offset k item) ...) (size n)) ...)
 (anchors (anchor chain segment offset) ...)
 (requests ...)
 (problems ...))
```

## 已知限制

- 还是扁平 item，没有 analyze/dce 的 blocks。
- 符号内存 displacement 在 `mem` 里标记成固定 disp32，`instruction-size` 用占位值量尺寸。
- `place` 只支持精确链锚点，没有 region / 通配。
- 越界的 short branch 产生 `needs-near` request，由 relax 消费。
- 越界的 near branch 产生 `needs-far` problem；far form 还没实现。
