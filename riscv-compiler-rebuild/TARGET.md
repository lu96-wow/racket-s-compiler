# target profile 设计

> 状态：已实现。target 是显式参数，不使用动态参数 / 全局 `current-target`。
>
> `run-flow`、`layout-program`、`relax`、`encode-layout`、`encode-instruction`
> 都把 target 作为参数传下去。

## 1. 数据模型

```racket
(struct target (xlen extensions) #:transparent)
```

- `xlen`：`'rv32 | 'rv64`
- `extensions`：已排序、无重复的 symbol 列表

端序固定为 little，不放进 target 字段。

不放：

- `name`：profile 变量名就是名字
- `endianness`：没有物理 big-endian 目标，统一 little
- `padding`：由 extensions 推导（有 C 才能用 `c.nop`）
- ABI / 栈 / scratch / reloc：都不属于 target

## 2. Profile

```racket
target-rv64-base    ; 当前行为：rv64 + 当前扩展
target-rv64-all     ; 所有 rv64_* + 非 rv32_* 扩展
target-rv32-all     ; 所有 rv32_* + 非 rv64_* 扩展
```

自定义 target 直接构造：

```racket
(target 'rv64 '(rv_i rv_m rv_a rv_c rv64_i rv64_m rv64_a))
```

不做自动扩展依赖闭包。  
`rv32_*` / `rv64_*` 不能混；由测试和构造检查，不搞常驻校验 API。

## 3. 显式传参

```racket
(integer->bytes width value)
(padding-bytes target kind n)

(item-size target x)
(layout-program target program data layout-input)
(relax target program data layout-input #:max-rounds 64)
(encode-layout target layout)

(encode-instruction target name operands)
(instruction-arity target name)
(known-instruction? target name)
```

没有 `current-target`，也没有 `make-parameter`。

各层需要 target 时只读传入的那个值：

```racket
(target-xlen target)
(target-extensions target)
```

## 4. flow

`target` 是 `run-flow` 的第一个参数：

```racket
(run-flow target-rv64-all default-flow seeds)
(run-stage target-rv64-base 'flatten seeds)
```

stage 的 run 函数签名是：

```racket
(lambda (target in) ...)
```

只有 layout / relax / encode 用 `target`，其它 stage 忽略。

target 不再放在 seed / context 里。

## 5. 指令缓存

`lookup-instruction` 的缓存键必须包含 target 的扩展集：

```racket
(cons (target-extensions target) name)
```

否则先查 rv64 再查 rv32 会复用错误结果。

## 6. 填充

`padding-bytes` 由传入 target 的扩展集推导：

- 4 字节：`nop`
- 2 字节：仅当 target 有 `rv_c` / `rv64_c` / `rv32_c` 时用 `c.nop`
- 奇数余数：报错

不单独加 padding 策略字段。

## 7. 已实现

- target 结构 + 内置 profile
- `integer->bytes` 固定 little；`padding-bytes` 显式 target
- `item-size` / `layout-program` / `relax` / `encode-layout` 显式 target
- `encode-instruction` / `instruction-arity` / `known-instruction?` 显式 target
- `run-flow` / `run-stage` 显式 target
- 指令缓存键带扩展集
- CSR 表按 XLEN 选择（rv32 才启用 csr32-table）
- 旧全局 `target-xlen` / `target-extensions` 已删除

## 8. 验证

1. **profile 构造检查**（测试里做）

```text
没有同时出现 rv32_* 和 rv64_*
所有 extension 都在 riscv-asm 的 extensions 里
```

2. **指令解析检查**

```racket
(known-instruction? target-rv64-all 'add)
```

不搞常驻 `validate-target` API。

## 9. 不在 target 里

- 操作数语法 / 寄存器类：`encode/syntax`
- 段 / place：`layout`
- 栈 / ABI / scratch：后续寄存器层
- reloc / loader：后续链接层

target 只回答：**多少位、开了哪些扩展。端序固定 little。**
