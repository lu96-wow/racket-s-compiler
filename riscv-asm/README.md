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
      parcel.rkt                RISC-V 指令长度（parcel）规则

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
        lookup.rkt             按扩展符号查 metadata 表的辅助模块

      codegen.rkt              指令模块生成
      info-codegen.rkt         instruction_info 生成
      render.rkt               Racket 模块三段式渲染
      instruction_paths.rkt    生成包内的路径辅助模块

  test/                         测试与测试数据
    field-ranges.rkt            操作数范围测试数据
    instruction-range-test.rkt  每条指令逐操作数范围测试
    parcel-test.rkt             长度（parcel）规则测试
    info-size-test.rkt          instruction_info 的 size 一致性测试
    info-lookup-test.rkt        instruction_info 查表辅助测试

  generated/                   自包含生成包
    lib/                       从 binary-build 复制的模块
      base.rkt
      bit.rkt
      instruction_paths.rkt
      riscv/
        raw/
        rebuilt/
        instruction_info/      struct.rkt / query.rkt / lookup.rkt
    gen/                       由 build 生成的模块
      riscv/
        instruction/
          raw/
          rebuilt/
        instruction_info/      <ext>.rkt / extensions.rkt / instruction_extensions.rkt

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

生成包分成两个顶层目录，显式区分文件来源：

```text
lib/   从 binary-build 原样复制的手写模块
 gen/   由 build 生成的模块
```

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
  lib/                         复制（手写）
    base.rkt
    bit.rkt
    instruction_paths.rkt
    riscv/
      raw/
      rebuilt/
      instruction_info/
        struct.rkt
        query.rkt
        lookup.rkt
  gen/                         生成
    riscv/
      instruction/
        raw/
        rebuilt/
      instruction_info/
        <ext>.rkt
        extensions.rkt
        instruction_extensions.rkt
```

`lib/instruction_paths.rkt` 提供：

```racket
(raw-instruction-path 'rv_i)
;; => ".../generated/gen/riscv/instruction/raw/rv_i.rkt"

(rebuilt-instruction-path 'rv_i)
;; => ".../generated/gen/riscv/instruction/rebuilt/rv_i.rkt"
```

返回绝对路径字符串，适合 `dynamic-require`。

`lib/riscv/instruction_info/lookup.rkt` 提供 metadata 的查表原语，同样接受扩展符号：

```racket
(instruction-info-extensions)
;; => '(rv32_c rv32_c_f ... rv_zvksh)  生成包里有 metadata 的扩展清单

(instruction-info-path 'rv_i)
;; => ".../generated/gen/riscv/instruction_info/rv_i.rkt"

(extension-instruction-info 'rv_i)
;; => 该扩展的全部 instruction-info 列表（模块只加载一次，结果缓存）

(find-extension-instruction-info 'rv_i 'add)
;; => add 的 instruction-info；找不到返回 #f
```

**不生成跨扩展总表**（没有 `all-instruction-info`）。同名指令在不同扩展下可能是
不同变体（`slli` 在 `rv32_i` 和 `rv64_i` 里操作数和 fixed fields 都不同），
所以查表必须先按目标 ISA 选扩展，再查对应扩展的表；用 `instruction->extensions`
可以得到某个名字的候选扩展集合。

两种路径辅助模块的职责分工：`instruction_paths.rkt` 给指令模块路径，
`instruction_info/lookup.rkt` 给 metadata 模块路径并负责加载成表。
两个模块都位于 `lib/`，内部根据自身位置定位 `gen/`。

metadata 对外统一用符号：

```racket
(instruction-info-name info)       ; => 'add
(instruction-info-extension info)  ; => 'rv_i
```

---

## 测试

运行：

```bash
raco test test/*.rkt
```

当前结果：

```text
26257 tests passed
```

### 1. 逐指令范围测试

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

### 2. 长度（parcel）规则测试

```text
test/parcel-test.rkt
```

用合成取位函数覆盖 `parcel.rkt` 的判定分支：

- 16 位：`bits[1:0] != 11`
- 32 位：`bits[1:0] == 11` 且 `bits[4:2] != 111`
- `bits[4:2] == 111`（48 位或更长）：报错
- `bits[1:0]` 未固定、`bits[4:2]` 不足以区分：报错

### 3. `size` 一致性测试

```text
test/info-size-test.rkt
```

对全部 generated info 验证 `size == width / 8`，且 `width` 只能是 16 或 32。

### 4. `instruction_info` 查表测试

```text
test/info-lookup-test.rkt
```

对全部扩展验证：

- `instruction-info-extensions` 列出的扩展无重复且有序
- 每个扩展的路径存在，表非空，表内扩展名正确、名字唯一
- `instruction->extensions` 与各扩展表双向一致
- `find-extension-instruction-info` 按名字命中/未命中
- 指令名与扩展名都是符号，传字符串报错
- 重复查表命中缓存，非符号参数报错

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
- `instruction-width` 由 `riscv/parcel.rkt` 的长度规则判定：`bits[1:0]` 必须固定；`bits[1:0] = 11` 时 `bits[4:2]` 必须能排除 `111`。否则报错。
- 当前编码器只支持 ≤32 位编码，48 位及以上的定义会被 `parcel.rkt` 直接拒绝。
- raw 字段函数接收完整逻辑值，并通过 `checked-field` 检查范围/对齐。
- raw 指令里 hi/lo 分片可能接收同一个完整立即数，因此分片共享完整逻辑范围。
- rebuilt 参数顺序等于逻辑操作数在源 token 中第一次出现的位置。
- 不生成跨扩展总表；同名指令按扩展分别保存，查询时先选扩展再查表。
- 生成包分 `lib/`（复制）与 `gen/`（生成）两层；`gen/` 下的模块用相对路径引用 `lib/`，因此 `lib/` 内部保留 `binary-build` 的目录结构。
