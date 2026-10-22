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
    *.rkt
    generate-oracle.sh
    extract-llvm-oracle.py
    oracle/
      llvm-encoding.json

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

  reference/
    range/                     旧 range 实现，仅测试对照用

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

运行全部测试：

```bash
raco test test/*.rkt
```

最近一次结果：

```text
10212 tests passed
```

### 测试分层

#### 1. 字段位生成测试

```text
scalar-test.rkt
compressed-test.rkt
vector-test.rkt
mop-test.rkt
instruction-test.rkt
```

覆盖：

- `bit` / `bit-range` / `bit-map`
- C 扩展非连续立即数
- `simm12` / `bimm12` / `zimm6` 等组合字段
- 压缩寄存器 bias
- raw / rebuilt 的典型指令一致性

#### 2. 解析测试

```text
parse-test.rkt
```

覆盖：

- standard / pseudo / import 解析
- fixed field 校验
- alias operand 保留
- 同名定义优先级
- 全量扩展文件解析

当前解析结果：

```text
891 standard
189 pseudo
155 imports
110 ratified extensions
```

#### 3. 生成模块测试

```text
generated-test.rkt
info-test.rkt
```

覆盖：

- 所有 raw / rebuilt / info 模块可加载
- raw / rebuilt 编码一致性
- alias / pseudo / import
- metadata 内容
- `instruction->extensions`
- 生成包路径辅助模块

#### 4. fixed-bit oracle 测试

```text
encoding-oracle-test.rkt
```

对比数据：

```text
riscv-opcodes/instr_dict.json
```

生成方式：

```bash
test/generate-oracle.sh
```

测试内容：

- 891 条 standard 指令
- 用 raw 函数生成编码
- 检查：

```racket
(= (bitwise-and word mask) match)
```

其中 `match/mask` 来自 riscv-opcodes 的 Python 实现。

当前结果：

```text
891 standard instructions compared
1783 checks passed
```

#### 5. 带操作数的 LLVM encoding 测试

数据源：

```text
/home/lu96/work/learn/llvm-project/llvm/test/MC/RISCV
```

提取脚本：

```bash
python3 test/extract-llvm-oracle.py \
  --llvm-test-dir /home/lu96/work/learn/llvm-project/llvm/test/MC/RISCV
```

生成数据：

```text
test/oracle/llvm-encoding.json
```

当前数据规模：

```text
615 个 .s 文件
2715 条 asm -> bytes 记录
1408 个 mnemonic
2 字节编码 476 条
4 字节编码 2239 条
```

测试文件：

```text
llvm-encoding-test.rkt
```

测试逻辑：

- 解析 LLVM 汇编文本中的简单操作数
- 映射到 rebuilt 指令参数
- 调用生成函数
- 与 LLVM 期望字节精确比较

当前结果：

```text
matched:   480
mismatched:  0
skipped:   2235
```

跳过的主要形式：

- `fli.*` 浮点立即数
- `c.lui` 的 6 位立即数语义
- `zext.h` / `rev8` 等 alias canonical 编码
- Zcb 的 `c.lbu` / `c.lhu` / `c.lh`
- relocation 表达式
- vector 复杂语法
- CSR / rounding mode / atomic 修饰符

这些不是已发现的编码错误，而是当前测试解析器尚未实现对应语义。

---

## 测试数据来源

### 1. `riscv-opcodes/extensions/*`

用途：

- 指令定义的唯一输入源
- standard / pseudo / import / fixed fields

### 2. `riscv-opcodes/instr_dict.json`

用途：

- fixed-bit oracle
- `match` / `mask` / `variable_fields`

生成：

```bash
test/generate-oracle.sh
```

### 3. LLVM MC/RISCV 测试

用途：

- 带操作数的最终编码数据
- assembly text -> expected bytes

本地源：

```text
/home/lu96/work/learn/llvm-project/llvm/test/MC/RISCV
```

### 4. `reference/range/`

用途：

- 旧 range 实现的对照
- 仅供 `scalar-test.rkt` 参考

---

## 已知边界

- 当前只生成 ratified 顶层扩展；`extensions/unratified` 不在生成范围内。
- `instruction-width` 必须能由 fixed bits 的 bit0/bit1 确定；否则报错。
- raw 字段函数接收完整逻辑值；raw 指令里 hi/lo 分片可能接收同一个完整立即数。
- rebuilt 参数顺序等于逻辑操作数在源 token 中第一次出现的位置。
- LLVM 测试数据是装配文本级数据；当前只解析稳定支持的标量/压缩子集。
- 生成包依赖通过镜像 `binary-build` 的目录布局来保持相对 `require` 有效。
