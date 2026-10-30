# bind-labels 地址绑定（`bind-labels/bind.rkt`）

> 速览（功能 / s-exp / 设计理由）：[`../SEXP.md#bind-labels`](../SEXP.md#bind-labels)。
>
> 把 measured-layout 的 `anchors` 落到绝对地址，产出 bound-layout。
> 核心公式只有一条：**绝对地址 = 段 start + 段内偏移**。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| `anchors` → `symbols`（加绝对地址） | 改 item / offset / size |
| 用最终地址检查 `(value w 值)` 的宽度 | 分支松弛（relax） |
| 用最终尺寸检查 `segment-overflow` | 填 scratch（寄存器层） |
| 原样保留 measured 的 `requests` / `problems` | 补 fallthrough 跳转 |
| 幂等：对 bound-layout 再调用返回原值 | 重定位 / 外部符号 / 链接 |

本层是**纯收尾**：不改布局，只把“位置”变成“地址”，再做两件只有最终地址/最终尺寸才能做的检查。

## 2. 输入 / 输出

输入 measured-layout：

```racket
((phase measured)
 (segments (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16)
                    (items (offset 0 (label main))
                           (offset 0 (ret)))
                    (size 4)) ...)
 (anchors (anchor (main) c 0) ...)
 (requests ...)
 (problems ...))
```

输出 bound-layout：

```racket
((phase bound)
 (segments ...)                     ; 和输入完全一样
 (anchors (anchor (main) c 0) ...)  ; 保留位置视图
 (symbols (symbol (main) c 0 #x100000) ...)
 (requests ...)                     ; 原样保留；没解决就由 encode 拒绝
 (problems ...))                    ; measured problems + value 宽度/段容量
```

`symbols` 行：`(symbol 链 段名 偏移 绝对地址)`。

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `bind-labels` | measured-layout | bound-layout |
| `bound-layout?` | 任意 layout | boolean |
| `layout-symbols` | bound-layout | `symbols` 列表 |
| `symbol-row` | `symbols` + 链 | 符号行 / `#f` |
| `symbol-address` | 符号行 | 绝对地址 |
| `eval-symbol-address` | 地址表达式 + `symbols` | 整数 |

`bind-labels` 不需要 `target`：地址绑定和 `value` 宽度都不依赖 XLEN。  
如果以后加入重定位，再由需要 base/XLEN 的实现扩展参数。

## 4. 规则

1. **只接受 measured-layout**：`phase` 不是 `measured` 且不是 `bound` 时报错。
2. **幂等**：`(bind-labels (bind-labels m)) = (bind-labels m)`。
3. **地址公式只在这里出现**：`address = segment.start + anchor.offset`。
4. **不改尺寸**：`segments` / `anchors` 原样带过去；`bind-labels` 之后不允许再改变 item/size。
5. **`value` 宽度在最终地址上查**：
   - 地址表达式用最终 `symbols` 求值；
   - 整数也查一遍（`data-items` 可能直接 seed，不经过 expand-data）。
6. **`segment-overflow` 用最终 `size` 查**：`size > end - start` 才报；`end <= start` 已经由 layout 报过 `segment-bad-range`。
7. **requests/problems 不在这里解决**：`needs-far` / `scratch-hole` / `la-too-far` 原样保留；`encode` 要求两者都空。
8. **不重复报 `undefined-target`**：链存在性是 measured 的职责；本层只在链都存在时求值。

## 5. 不归本层管

- `needs-far`：relax。
- `scratch-hole` / `la-too-far`：未来的寄存器使用层。
- `undefined-target`：layout（链身份不随松弛变化）。
- 指令合法性 / 编码：encode 与 `riscv-asm`。
- 重定位 / 外部符号 / 段基址可变：未来的 link/reloc 层。

## 6. 测试

`bind-labels/test.rkt`：

- measured → bound 的 phase / symbols / 地址公式；
- anchors / segments 原样保留；
- 幂等；
- `value` 宽度（地址表达式 + 整数）；
- `segment-overflow`；
- requests / problems 原样保留；
- `eval-symbol-address` / `symbol-row` / `symbol-address`；
- 非 measured 输入报错。

黑盒契约测试：`../riscv-compiler-test/bind-labels-test.rkt`。

## 7. 已知缺口

- 没有重定位：段基址必须由 `layout-spec` 的 `start` 固定。
- 没有外部符号 / GOT / PLT。
- 没有 `la` 远形式；`la-too-far` 只是交给未来寄存器层的 request。
- 如果未来段可重定位，`align` 的填充也可能变成重定位，而不是固定的 `(pad n)`。
