# loko-compat（旧汇编写法 → 核心 item）

> 只做写法兼容。输入和输出都是 s-expression；没有布局、地址、编码，也没有
> 跨调用状态。目标是把 Loko `arch/amd64` 现在吐出的汇编写法接到本后端。

## 1. 作用

把 Loko `arch/amd64` 的旧汇编写法纯变换成本后端的核心 item。

## 2. 相关 s-exp：输入

```scheme
(loko-source
  (text item ...)   ; Loko 的 text / 代码
  (data item ...))  ; Loko 的 data / 数据
```

分开 `text` / `data` 是有意的：Loko 的 `%section` / `%comm` / `%call` 属于
image 层，不属于“写法兼容”。本层只接 codegen 能产生的普通 text/data。

`translate-loko-text-only` / `translate-loko-data-only` 是单边便利入口；如果代码引用了
另一边的 `%equiv`，用 `translate-loko-source`。

## 3. 相关 s-exp：输出

```scheme
(loko-compat
  (program-items item ...)
  (data-items item ...)
  (aliases (alias 名字 值) ...)
  (problems problem ...))
```

- `program-items` / `data-items` 已经是本后端的核心 item。
- `aliases` 是 `%equiv` 解析后的常量/地址表达式，供 image 层或调试使用。
- `problems` 是明确的问题列表；`flow/flow.rkt` 在非空时报错。

## 4. 映射

| Loko 写法 | 核心写法 | 说明 |
| --- | --- | --- |
| `(mem64+ ...)` / `(mem32+ ...)` / `(mem+ ...)` | `(b64 ...)` / `(b32 ...)` / `(bN ...)` | `mem+` 从兄弟寄存器或基址推断宽度 |
| `(mem128+ ...)` | `(b128 ...)` | 用于 `movdqa` 等 SSE 内存操作数 |
| `(%label x)` | `(label x)` | symbol/string/number 保留原名；vector 等映射为 `loko-label-N` |
| `(%label a b)` | `(label a b)` | 同地址多名字；end/section metadata 留给 image 层 |
| `(%comment ...)` | `(comment ...)` | 零尺寸注记 |
| `(%align n)` / `(%align n 0)` | `(align n)` | 显式非零填充字节暂不支持 |
| `(%u8 v)` / `(%u16 v)` / `(%u32 v)` / `(%u64 v)` | `(value 1/2/4/8 v)` | 一条可展开成多条 |
| `(%u128 n)` | 两条 `(value 8 ...)` | 只支持整数；符号 128 位表达式显式报问题 |
| `(%vu8 bv)` | `(bytes ...)` | 字节原样 |
| `(%utf8z s)` | `(bytes ... 0)` | UTF-8 + NUL |
| `(%equiv name expr)` | `(alias name expr)` | 定义先收集，引用处内联 |
| `sal` | `shl` | 同一编码 |
| `movsxd` | `movsx` | 32 → 64 符号扩展 |
| `sete` / `setc` / `setnp` … | `(setcc cc rm)` | 条件码别名 |
| `cmovnc` / `cmovz` … | `(cmovcc cc dst src)` | 条件码别名 |
| `lock.xadd` / `rep.movs` … | `(prefix lock (xadd …))` / `(prefix rep (movs …))` | 前缀变成显式 form |
| `(call (mem...))` | `(call-indirect mem)` | 直接调用留给 expand-pseudo |
| `(jmp (mem...))` | `(jmp-indirect mem)` | 直接跳转留给 expand-pseudo |

## 5. 边界：不在这里做的事

以下写法反映的是 image/链接事实，不是单纯拼写：

```text
%section  %origin  %comm  %mode  %call
```

本层把它们变成 `(problem directive-needs-image-layer ...)`，不猜位置、不生成
bss、不调用宿主过程。等 image 层设计好后再接。

`$`（当前 IP）和带标签的 `bitwise-*` / `shift` 表达式也不在这里硬解释：
它们要么需要布局期地址，要么需要扩展核心地址表达式。当前显式报
`current-ip-expression` / `symbolic-bit-expression`。

## 6. 设计思路：纯函数

- 输入列表不被修改。
- 标签表、别名表、问题列表都是本次调用的局部数据。
- 输出只依赖输入；同样的输入得到同样的输出（匿名标签编号按遍历顺序固定）。
- 不 require `layout` / `encode` / `flow`，避免反向依赖。

## 7. 边界 / 测试

```sh
racket amd64/loko-compat/test.rkt
```
