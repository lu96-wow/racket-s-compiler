# check（`check.rkt`）

## 作用

在 `layout` 之后、`bind-labels` 之前检查**前端显式选择的控制转移/地址形式**是否成立。

```text
layout  -> check -> bind-labels -> encode
```

本层只报 `problems`，不产生 `requests`，不改 item / offset / size。

## 相关 s-exp

输入输出都是 measured-layout：

```racket
((phase measured)
 (origin 镜像基址)
 (externs (symbol 链 地址|#f) …)
 (segments (segment (name …) (kind …) (start …) (end …) (align …)
                    (items (offset k item) …)
                    (size n)) …)
 (anchors (anchor 链 段名 偏移) …)
 (problems …))
```

本层认识的形式：

```racket
(beq L rs1 rs2)                  ; 短形式, ±4 KiB
(c.beqz rs1 L)                   ; 短形式, ±256 B
(jal rd L)                       ; 短形式, ±1 MiB
(j L)                            ; 短形式, ±1 MiB

(branch-jal cond rs1 rs2 L)             ; 反向分支 + jal, 目标在 ±1 MiB
(branch-auipc-jalr tmp cond rs1 rs2 L)  ; 反向分支 + auipc+jalr
(jump-auipc-jalr link base L)           ; auipc base + jalr link

(la-pcrel rd expr)                      ; 近形式 auipc+addi
(la-pcrel-li-add rd tmp expr)           ; 显式远形式, tmp 必需
```

## 检查内容

| 检查 | problem |
| --- | --- |
| 控制转移目标不存在 | `undefined-target` |
| 目标地址不是偶数 | `misaligned-target` |
| 短形式/`branch-jal` 超出自己的 range | `out-of-range` |
| `branch-auipc-jalr` / `jump-auipc-jalr` 的 delta 超出 `auipc+jalr` | `out-of-range` |
| scratch/base/tmp 是零寄存器 | `zero-scratch` |
| `la-pcrel-li-add` 的 tmp 和 rd 重合 | `bad-scratch` |
| 近 `la` 超出 `auipc+addi` | `la-too-far` |
| 地址表达式里的链不存在 | `undefined-target` |
| 外部符号冲突 / 未链接 / 奇数地址 | `external-conflict` / `unlinked-external` / `misaligned-external` |

## 边界

- 不选形式：短形式不够远就是错误，前端必须显式改写成 `branch-jal` / `branch-auipc-jalr` / `jump-auipc-jalr`。
- 不升形式：没有 `needs-far` 之类的交接点。
- scratch/base/tmp 都是必需操作数，没有“空槽”；只检查值是否合法。
- 不改尺寸：`segments` / `anchors` 原样传下去，只追加 `problems`。
- 近 `la` 不够远时只报 `la-too-far`，不会自动改成 `la-pcrel-li-add`。
