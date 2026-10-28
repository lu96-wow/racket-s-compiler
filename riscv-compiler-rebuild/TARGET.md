# target profile 设计

> 状态：已实现。`current-target` 由 `run-flow` 从 seed 绑定；旧全局常量已删除。

> 目标：让 rv32 / rv64 / 不同扩展集可切换，但**不把 target 参数塞进每个函数**。
>
> 做法：target 是一个简单值 + 一个动态参数 `current-target`；
> `run-flow` 从 seed 里取 target 并 `parameterize`，各层函数签名保持不变。

## 1. 数据模型

只保留真正需要的三个事实：

```racket
(struct target (xlen endianness extensions) #:transparent)
```

- `xlen`：`'rv32 | 'rv64`
- `endianness`：`'little | 'big`
- `extensions`：已排序、无重复的 symbol 列表

不放：

- `name`：profile 的变量名就是名字
- `padding`：由 extensions 推导（有 C 才能用 `c.nop`）
- ABI / 栈 / scratch / reloc：都不属于 target

## 2. Profile

```racket
target-default      ; 当前行为：rv64 + 当前扩展
target-rv64-base    ; 同 target-default
target-rv64-all     ; 所有 rv64_* + 非 rv32_* 扩展
target-rv32-all     ; 所有 rv32_* + 非 rv64_* 扩展
```

需要自定义时直接构造：

```racket
(target 'rv64 'little '(rv_i rv_m rv_a rv_c rv64_i rv64_m rv64_a))
```

不做自动扩展依赖闭包。  
`rv32_*` / `rv64_*` 不能混；这个由构造/测试检查，不搞复杂校验 API。

## 3. 当前 target

```racket
(define current-target (make-parameter target-default))

;; 访问
(target-xlen (current-target))
(target-endianness (current-target))
(target-extensions (current-target))
```

各层**不接收 target 参数**，只读 `current-target`：

- `integer->bytes`：读 `target-endianness`
- `padding-bytes`：读 `target-extensions`（C 扩展决定 2 字节填充）
- `layout` 的 `li` 尺寸 / `la` 判据：读 `target-xlen`
- `encode` 的指令查找 / `li` 展开：读 `target-xlen`、`target-extensions`

函数签名保持不变。

## 4. flow 接入

`target` 是 seed，可选：

```racket
(run-flow default-flow
          '((target . target-rv64-all)
            (rich-data . …)
            (program-items . …)
            (layout-spec . …)))
```

`run-flow` 开始时：

```racket
(parameterize ([current-target (hash-ref ctx 'target target-default)])
  ...跑各层...)
```

不传 target 就用 `target-default`，所以现有调用不用改。  
`run-stage` 也走 `run-flow`，因此自动支持 target seed。

## 5. 指令缓存

`lookup-instruction` 的缓存键必须包含当前扩展集：

```racket
(cons (target-extensions (current-target)) name)
```

否则先查 rv64 再查 rv32 会复用错误结果。  
这是实现里唯一必须注意 state 的地方。

## 6. 填充

`padding-bytes` 从 `current-target` 的扩展集推导：

- 4 字节：`nop`
- 2 字节：仅当 target 有 `rv_c` / `rv64_c` / `rv32_c` 时用 `c.nop`
- 奇数余数：报错

不单独加 padding 策略字段。以后真需要 ebreak/0xFF 填充时再加。

## 7. 实施顺序（已完成）

### 1. target 值和参数（已完成）

```racket
(struct target ...)
target-default
target-rv64-base
target-rv64-all
target-rv32-all
current-target
```


### 2. 内部改读 current-target（已完成）

- `integer->bytes` / `padding-bytes`
- `layout` 的 `li` / `la`
- `encode` 的 lookup / `li`
- lookup 缓存键
- CSR 表按 XLEN 选择（rv32 才启用 csr32-table）

### 3. flow 绑定 target（已完成）

- `run-flow` 从 seed 取 `target`，参数化 `current-target`
- 测试/demo 想换 target 就加 `(target . target-rv64-all)`
- 全扩展 profile 用 `syntax-coverage` 看语法缺项

### 4. 删除旧常量（已完成）

- 删除 `target-xlen` / `target-endianness` / `target-extensions` 兼容导出
- 统一走 `current-target` + 访问器

## 8. 验证

只保留两类简单检查：

1. **profile 构造检查**（测试里做）

```text
没有同时出现 rv32_* 和 rv64_*
所有 extension 都在 riscv-asm 的 extensions 里
```

2. **指令解析检查**

```racket
(parameterize ([current-target target-rv64-all])
  ...resolve 指令...)
```

不搞常驻 `validate-target` API。

## 9. 不在 target 里

- 操作数语法 / 寄存器类：`encode/syntax`
- 段 / place：`layout`
- 栈 / ABI / scratch：后续寄存器层
- reloc / loader：后续链接层

target 只回答：**多少位、什么端序、开了哪些扩展。**
