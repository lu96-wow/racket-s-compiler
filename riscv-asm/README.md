# riscv-asm

RISC-V 指令编码生成器与测试数据整理。

当前实现从 `riscv-opcodes` 源文件生成：

- raw 指令模块
- rebuilt 指令模块
- instruction metadata
- 自包含生成包
- 生成包路径辅助模块

---

## 目录结构

```text
riscv-asm/
  binary-build/                 生成器源码
    base.rkt                   底层宏表面
    bit.rkt                    位组合实现
    build.rkt                  构建入口
    paths.rkt                  路径与生成布局唯一配置点

    riscv/
      parse/                   解析层
        struct.rkt             源文件数据结构
        field.rkt              数字/fixed field 解析
        line.rkt               单行、pseudo、import 解析
        operand.rkt            alias operand 解析
        query.rkt              fixed field 查询、指令宽度
        resolve.rkt            import/pseudo/重名合并
        file.rkt               文件级解析
        main.rkt               解析层聚合入口

      raw/                     原始表示字段函数
        scalar.rkt
        compressed.rkt
        vector.rkt
        mop.rkt

      rebuilt/                 重建表示字段函数
        scalar.rkt
        compressed.rkt
        vector.rkt
        mop.rkt

      instruction_info/
        struct.rkt             metadata 结构
        query.rkt              metadata 查询

      codegen.rkt              指令模块生成
      info-codegen.rkt         instruction_info 生成
      render.rkt               Racket 模块三段式渲染
      instruction_paths.rkt    生成包内的路径辅助模块

  test/                         测试与测试数据
    field-ranges.rkt            操作数范围测试数据
    instruction-range-test.rkt  每条指令逐操作数范围测试

  generated/                   自包含生成包
    base.rkt
    bit.rkt
    instruction_paths.rkt
    riscv/
      raw/
      rebuilt/
      instruction/
        raw/
        rebuilt/
      instruction_info/

  riscv-opcodes/               外部 RISC-V opcodes 源
```

---

## 构建

在 `riscv-asm/` 目录下：

```bash
racket binary-build/build.rkt
```

默认生成到：

```text
riscv-asm/generated/
```

也可以指定输出根目录：

```bash
racket binary-build/build.rkt /tmp/riscv-asm-generated
```

构建时会：

1. 解析 `riscv-opcodes/extensions/` 顶层的 ratified 扩展
2. 解析 `$import` 和 `$pseudo_op`
3. 按优先级合并同名定义
4. 生成 raw / rebuilt 指令模块
5. 生成 instruction_info
6. 复制依赖模块到生成包
7. 生成 `instruction_paths.rkt`
8. 清理旧的已知生成路径，避免残留文件

当前生成统计：

```text
ratified extensions: 110
standard definitions: 891
pseudo definitions:   189
import definitions:   155
emitted definitions:  1232
skipped duplicates:   3
```

同名定义优先级：

```text
1. 当前扩展的 standard 定义
2. import 进来的 standard 定义
3. 与所依赖 standard 指令 fixed fields 兼容的 pseudo
4. 其他 pseudo（兜底，并记录 ambiguous-pseudo）
```

当前跳过的重名：

```text
jal:  overridden-by-standard-definition
jalr: overridden-by-standard-definition
ld:   not-a-standard-form
```

---

## 生成包

生成包是自包含的：

```text
generated/
  base.rkt
  bit.rkt
  instruction_paths.rkt
  riscv/
    raw/
    rebuilt/
    instruction/
      raw/
      rebuilt/
    instruction_info/
```

`instruction_paths.rkt` 提供：

```racket
(raw-instruction-path 'rv_i)
;; => ".../generated/riscv/instruction/raw/rv_i.rkt"

(rebuilt-instruction-path 'rv_i)
;; => ".../generated/riscv/instruction/rebuilt/rv_i.rkt"
```

返回绝对路径字符串，适合 `dynamic-require`。

---

## 测试

运行：

```bash
raco test test/*.rkt
```

当前结果：

```text
19410 tests passed
```

### 唯一测试：逐指令范围测试

```text
test/field-ranges.rkt
test/instruction-range-test.rkt
```

生产代码中的 `checked-field` 负责范围/对齐校验。测试对全部 generated 指令逐操作数验证：

- 每条指令
- 每个操作数
- 合法值：`0`、`+1`、`-1`、`min`、`max`（只要在范围内）
- 非法值：`min-1`、`max+1`、未对齐值

合法值必须成功编码，非法值必须抛错。

当前覆盖：

```text
instructions: 1232
checked values: 18175
```

---

## 测试数据来源

### 1. `riscv-opcodes/extensions/*`

指令定义、fixed fields、pseudo/import 的唯一输入源。

### 2. `test/field-ranges.rkt`

测试用操作数范围数据：

```racket
(min max align)
```

用于生成合法值、越界值和未对齐值。

---

## 已知边界

- 当前只生成 ratified 顶层扩展；`extensions/unratified` 不在生成范围内。
- `instruction-width` 必须能由 fixed bits 的 bit0/bit1 确定；否则报错。
- raw 字段函数接收完整逻辑值，并通过 `checked-field` 检查范围/对齐。
- raw 指令里 hi/lo 分片可能接收同一个完整立即数，因此分片共享完整逻辑范围。
- rebuilt 参数顺序等于逻辑操作数在源 token 中第一次出现的位置。
- 生成包依赖通过镜像 `binary-build` 的目录布局来保持相对 `require` 有效。
