# flatten 模块展平 + 链式查表（`flatten/flatten.rkt`）

> 只做**名字**，不做指令。输出里所有 label 链带上完整作用域前缀，所有引用改写成完整链。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| `(module a (module b …))` 逐层加前缀 | 认识任何助记符 |
| 建"完整链 → 位置"表 | 段 / 偏移 / 尺寸 |
| 按"内层优先"解析引用 | 判断 item 是否合法 |
| 多输入共享一张名字表 | 改 item 的**形状**（只重写操作数里的链） |

## 2. 输入 / 输出

```racket
;; 输入: 多个输入，每个是 item 列表
(flatten-inputs (list src1 src2 ...))
  -> (values (listof (listof item)) 名字表)

;; 单个输入
(flatten-program items) -> (listof item)
(flatten-items items)   -> (values (listof item) 名字表)
```

名字表 = `hash: 完整链 -> 位置序号`（序号 = 第几段连续的 label 组）。

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `flatten-inputs` | 多个输入的列表 | `(values 展平后的各输入 名字表)` |
| `flatten-program` | 单个输入 | 展平后的 item 列表 |
| `flatten-items` | 单个输入 | `(values (listof (listof item)) 名字表)`（与 `flatten-inputs` 同形） |
| `name?` / `path?` | 任意 | 布尔 |

名字 = `symbol | string | number`；链 = 非空名字列表。

## 4. 规则

1. **展平**：`(module a (label b c))` → `(label a b c)`；可任意嵌套，一层一个前缀。
2. **表**：连续写的多条 label 是**同一个位置**（同一序号、多个名字）：
   ```racket
   (label a f)
   (label a g)      ; 同一位置的第二个名字
   ```
   同一条链出现在**两个不同位置** → 报错（`label is defined in two places`）。
3. **链式查表**：引用 `r` 出现在作用域链 `s` 上时，依次试
   `s++r`, `s[0..-2]++r`, …, `r`，第一个命中的赢（内层遮蔽外层）。
4. **只重写链**：操作数里是 `path?` 的才改写；裸原子（寄存器、立即数）不动。
   所以本层**不需要认识任何助记符**。
5. 多输入**共享一张表**，所以程序里能引用另一个输入里定义的数据 label。

## 5. 不归本层管

- 指令拼写、伪指令展开（expand-pseudo）。
- 段、地址、尺寸（layout）。
- `li` / `la` 的语义（encode）。

## 6. 测试（`flatten/test.rkt`，43 条）

嵌套展平、同名遮蔽、跨输入引用、重复定义报错、链重写不动裸原子。

## 7. 已知缺口

无。
