# racket-s-compiler 命名规范与功能参考

## 目录结构

```
Binary_Build/      二进制指令编码构建
  build.rkt        编排入口，组合 discover→parse→generate→write 管道
  base.rkt         位域操作宏
  riscv-opcodes/   外部源 (git clone riscv/riscv-opcodes，.gitignore 排除)
  riscv/
    parse/         解析层：源文件 → 结构化数据
    codegen.rkt    代码生成：结构化数据 → Racket 代码字符串
    base_range.rkt 操作数位域函数 (rs1, imm12, bimm12…)
    register.rkt   寄存器编号常量 (x0-x31, f0-f31, ABI别名)
    instruction/   [生成] 指令定义文件
    instruction_info/ [生成] 元数据文件

Lang_Build/        汇编语言层
Design/            设计实验
Help-Tool/         辅助工具
```

## 文件名

### 构建工具（源码）

| 文件 | 功能 |
|---|---|
| `base.rkt` | 位域宏: `bit-range`, `make-instruction` |
| `base_range.rkt` | RISC-V 操作数值域函数: `rs1`, `rs2`, `rd`, `imm12`, `bimm12`... |
| `register.rkt` | 寄存器常量: `x0`-`x31`, `zero`, `ra`, `sp`, `a0`-`a7`... |
| `parse/struct.rkt` | 解析数据结构定义 |
| `parse/field.rkt` | 数字解析 + 固定字段 (`a..b=val`) 的识别与解析 |
| `parse/line.rkt` | 行过滤、hi/lo 后缀合并、`parse-line` |
| `parse/file.rkt` | `parse-file` 文件读取 + `make-extension-source` |
| `parse/main.rkt` | 聚合入口，re-export 全部 parse 模块 |
| `codegen.rkt` | 代码生成: `gen-*-file-content`、`classify-operand` |

### 生成文件

| 目录/文件 | 命名规则 | 数量 |
|---|---|---|
| `instruction/rv_*.rkt` | 与源文件名相同 | 109 |
| `instruction_info/rv_*.rkt` | 与源文件名相同 | 109 |
| `instruction_info/instruction_info.rkt` | 全局：指令→扩展映射 | 1 |
| `instruction_info/instruction_meta.rkt` | 全局：合并所有指令元数据 | 1 |
| `instruction_info/instruction_counts.rkt` | 全局：统计数据 | 1 |

`rv_*` 命名对应 RISC-V 扩展标准名：
- `rv_i` `rv_m` `rv_a` `rv_f` `rv_d` `rv_c` `rv_v` — 基础扩展
- `rv32_i` `rv64_i` — 位宽限定
- `rv_zicsr` `rv_zba` `rv_zfh` — 标准 Z 扩展
- `rv_d_zfa` `rv_q_zfhmin` — 交叉扩展 (扩展A下的扩展B增量)

---

## 函数命名规则

| 前缀/后缀 | 含义 | 示例 |
|---|---|---|
| `make-*` | 构造函数 | `make-instruction`, `make-extension-source` |
| `parse-*` | 解析函数 | `parse-line`, `parse-file`, `parse-fixed-field` |
| `gen-*` | 生成函数 (返回字符串，不写盘) | `gen-instruction-code`, `gen-*-content` |
| `*?` 后缀 | 谓词 | `skip-line?`, `hi/lo-suffix?` |
| `looks-like-*?` | 格式识别 (不解析) | `looks-like-fixed-field?` |
| `string->*` | 字符串转换 | `string->integer` |
| `strip-*` | 去除/规范化 | `strip-hi/lo` |
| `{ext}-get-*` | 扩展内查询 | `rv_i-get-param-count` |
| `{ext}-exists?` | 扩展内存在判断 | `rv_i-exists?` |
| `get-*` | 全局查询 | `get-param-count`, `get-extensions` |

---

## 全部导出函数

### base.rkt — 位域宏

| 函数 | 签名 | 功能 |
|---|---|---|
| `bit-range` | `(a b c d) → (integer → integer)` | 输入位[a,b]映射到输出位[c,d] |
| `bit-range` | `(x y) → (integer → integer)` | 单比特 x 移到 y |
| `bit-range-fixed` | `(a b val) → (any → integer)` | 固定值 val 写入位[a,b] |
| `bit-range-split` | `(f ...) → (integer → integer)` | 合并多个 bit-range (同数据源) |
| `bit-range-fixed-split` | `(f ... val) → (any → integer)` | 合并多个 bit-range-fixed |
| `make-instruction` | `(f ...) → (args... → integer)` | 将位域函数串成一条指令 |

### base_range.rkt — 操作数位域

| 类型 | 函数 | 位宽 | 对应指令格式 |
|---|---|---|---|
| 寄存器 | `rs1` `rs2` `rd` | 5-bit | bits[15:19][20:24][7:11] |
| I型立即数 | `imm12` | 12-bit signed | bits[20:31] |
| S型立即数 | `simm12` | 12-bit signed | bits[25:31]+[7:11] |
| B型偏移 | `bimm12` | 12-bit signed | bits[7]+[8:11]+[25:30]+[31] |
| J型偏移 | `jimm20` | 20-bit signed | bits[31]+[21:30]+[20]+[12:19] |
| U型立即数 | `imm20` | 20-bit | bits[12:31] |
| fence | `fm` `pred` `succ` | 4-bit | |
| 移位量 | `shamtw` `shamtd` | 5/6-bit | RV32/64 |
| fence标志 | `PI` `PO` `PR` `PW` `SI` `SO` `SR` `SW` | 常量 | |

每个字段函数含范围检查，越界报错。

### register.rkt — 寄存器常量

整数 x0-x31 (0–31)，ABI别名：`zero`(0) `ra`(1) `sp`(2) `gp`(3) `tp`(4) `t0-6`(5-7,28-31) `s0-11`(8-9,18-27) `a0-7`(10-17) `fp`(8)

浮点 f0-f31 (0–31)，ABI别名：`ft0-11` `fs0-11` `fa0-7`

### parse/ — 解析层

**数据结构 (struct.rkt)**

| struct | 字段 | 含义 |
|---|---|---|
| `fixed-field` | `high low value` | 固定位域 bits[high..low]=value |
| `instruction-def` | `name operands fixed-fields` | 一条解析后的指令 |
| `extension-source` | `path type-sym` | 源文件路径 + 扩展类型符号 |
| `extension-defs` | `source defs` | 扩展源 + 解析结果 |

每个 struct 自动附带 `?` 谓词和字段访问器。

**解析函数 (field.rkt)**

| 函数 | 功能 |
|---|---|
| `string->integer s n` | 支持 #x/#b/#o/0x/0b/0o/十进制 |
| `looks-like-multi-bit? s` | `"6..2=0x0D"` → `#t` |
| `looks-like-single-bit? s` | `"25=1"` → `#t` |
| `looks-like-fixed-field? s` | 合二为一 |
| `parse-fixed-field token n` | token → `fixed-field` struct |

**行解析 (line.rkt)**

| 函数 | 功能 |
|---|---|
| `skip-line? line` | 空行/`#`注释/`$pseudo_op`/`$import` → `#t` |
| `hi/lo-suffix? s` | `"imm12hi"` → `#t` |
| `strip-hi/lo s` | `"imm12hi"` → `"imm12"` |
| `parse-line line n` | 一行 → `instruction-def` 或 `#f` |

**文件操作 (file.rkt)**

| 函数 | 功能 |
|---|---|
| `parse-file path` | 文件 → `(listof instruction-def)` |
| `make-extension-source path` | 路径 → `extension-source` |

### codegen.rkt — 代码生成

| 函数 | 输入 → 输出 |
|---|---|
| `gen-instruction-code` | `instruction-def` → `"(define addi (make-instruction ...))"` 字符串 |
| `gen-instruction-file-content` | `(listof instruction-def)` → 完整 .rkt 文件内容 |
| `gen-instruction-info-file-content` | `type-sym` + `(listof instruction-def)` → info .rkt 文件内容 |
| `gen-global-extension-map-content` | `(listof extension-source)` → 全局映射文件 |
| `gen-global-instruction-meta-content` | `(listof extension-source)` → 全局元数据文件 |
| `gen-instruction-counts-content` | `(listof extension-source)` → 统计文件 |

**辅助**

| 函数 | 功能 | 示例 |
|---|---|---|
| `classify-operand name` | 操作数名 → `'reg\|'imm\|'csr\|'vec` | `"rs1"` → `'reg` |
| `extension-width sym` | 扩展 → 指令宽度 | `'rv_c` → `16`, `'rv_i` → `32` |
| `asm-format name ops` | 拼接汇编格式 | `"addi" '("rd" "rs1" "imm")` → `"addi rd, rs1, imm"` |

---

## 生成文件查询 API

### 按扩展查询（每个 `instruction_info/rv_*.rkt`）

```
(require "riscv/instruction_info/rv_i.rkt")
```

| 数据 | 类型 | 取值示例 |
|---|---|---|
| `rv_i-fields` | `(listof symbol)` | `'(rd imm20 rs1 imm12 bimm12 rs2 ...)` |
| `rv_i-width` | `16` 或 `32` | `32` |
| `rv_i-rd` | `hash` | `'((lui . 1) (addi . 1) (fence . 5) ...)` |
| `rv_i-param-count` | `hash` | `'((addi . 3) (lui . 2) (ecall . 0) ...)` |
| `rv_i-operands` | `hash` | `'((addi . (rd rs1 imm12)) ...)` |
| `rv_i-asm` | `hash` | `'((addi . "addi rd, rs1, imm12") ...)` |
| `rv_i-operand-types` | `hash` | `'((addi . (reg reg imm)) (csrrw . (reg reg csr)) ...)` |

| 查询函数 | 返回 |
|---|---|
| `(rv_i-exists? 'addi)` | `#t` |
| `(rv_i-get-param-count 'addi)` | `3` |
| `(rv_i-get-operands 'addi)` | `'(rd rs1 imm12)` |
| `(rv_i-get-asm 'addi)` | `"addi rd, rs1, imm12"` |
| `(rv_i-get-operand-types 'addi)` | `'(reg reg imm)` |
| `(rv_i-get-width)` | `32` |
| `(rv_i-get-field-position 'addi 'rs1)` | `2` |

### 全局查询（3个文件）

```
(require "riscv/instruction_info/instruction_info.rkt")  ← 指令→扩展
(require "riscv/instruction_info/instruction_meta.rkt")  ← 指令元数据
(require "riscv/instruction_info/instruction_counts.rkt") ← 统计
```

**指令→扩展**

| 函数 | 返回 |
|---|---|
| `(get-extensions 'addi)` | `'(rv_i)` |
| `(get-primary-extension 'addi)` | `'rv_i` |
| `(instruction-in-extension? 'addi 'rv_i)` | `#t` |

**指令元数据**

| 函数 | 返回 |
|---|---|
| `(get-param-count 'addi)` | `3` |
| `(get-operands 'addi)` | `'(rd rs1 imm12)` |
| `(get-asm-format 'addi)` | `"addi rd, rs1, imm12"` |
| `(get-operand-types 'addi)` | `'(reg reg imm)` |
| `(get-instruction-width 'addi)` | `32` |

**统计**

| 函数 | 返回 |
|---|---|
| `total-unique-instructions` | `883` |
| `(get-extension-instruction-count 'rv_i)` | `37` |
| `(list-all-extensions)` | `'(rv32_c rv32_c_f ...)` |
| `(valid-extension? 'rv_i)` | `#t` |
