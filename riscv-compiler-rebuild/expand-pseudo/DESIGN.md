# expand-pseudo 伪指令替换（`expand-pseudo/rewrite.rkt` + `table*.rkt`）

> 一张表 + 一次统一 rewrite。逻辑在 `rewrite.rkt`，数据在 `table-base.rkt` / `table.rkt`。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| 按表把伪指令展开成真指令 | 判断展开结果是不是真指令 |
| 一条 item 可以变成多条 | 管尺寸 / 地址 / 段 |
| 从外到内走到不动点 | 处理 `li` / `la`（它们要最终地址，属于 encode） |

## 2. 输入 / 输出

```racket
'((load-32 t0 sp 8) (jal x0 (done)))
  ↓ rewrite-program
'((lwu t0 sp 8) (jal x0 (done)))        ; 同形，里面已按表换过
```

不认识的**头**、形状不对的 form、原子、`quote` 数据 → 原样透传，不报错。

## 3. API

| API | 输入 | 输出 |
| --- | --- | --- |
| `rewrite-program` | item 列表 | item 列表 |
| `rewrite-tree` | item / 树 / 原子 | 同形 |
| `expand-item` | 单条 | 单条（展开到不再命中） |
| `apply-rule` | 单条 | 单条 / `#f`（只跑一次规则） |
| `make-table` / `check-rows` | 行表 | table / void |
| `pseudo-leftover?` / `fully-rewritten?` | item 列表 / 单条 | 布尔 |
| 数据：`rewrite-rows` `default-table` `rules` `rules-for` `directive-heads` `reserved-heads` | — | — |

## 4. 规则

一行 = **若干平级名字** + **若干 `(操作数模式 → 展开结果)`**：

```racket
(load-32 lw
 ((?d ?a)      (lw ?d ?a 0))
 ((?d ?a ?off) (lw ?d ?a ?off)))
```

1. **名字平级**：`load-8` 和 `l8` 是同级两种写法，谁做头都按同一组规则展开。
2. `?x` 是模式变量；同一变量重复出现必须匹配 `equal?` 的值；其余符号/数字字面匹配。
3. **从外到内走一遍即收敛**（对结果再跑一次是不动点）；表里写出自环 → `check-rows` 报错。
4. 加一种写法 = 名字段加一个 symbol；加一种形状 = 加一条规则；加伪指令 = 加一行。
5. 新扩展只要 `require` 一个 `xxx-rewrite-rows` 再 `append`，`rewrite.rkt` 一行都不用改。

## 5. 不归本层管

- **结果是不是真指令**：RISC-V 指令/扩展太多，名单不在这里维护；后端不认识自然报错。
- 尺寸：展开后每条都还是"未知长度的 item"，尺寸属于 layout。
- `li` / `la`：不进表，源样透传到 encode（见 encode 的 `li`/`la` 一节）。

## 6. 测试（`expand-pseudo/test.rkt`，119 条）

每行规则的形状、默认偏移补 0、别名平级、自环检测、透传（原子 / `quote` / 未知头）。

## 7. 已知缺口

- `directive-heads` 里的 `global` / `reserve` 还没有真正的语义（占位）。
