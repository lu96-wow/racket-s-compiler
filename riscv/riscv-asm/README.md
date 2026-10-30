# riscv-asm

RISC-V 指令编码生成器、metadata 生成器与运行时查表包。

当前实现是 `riscv-asm` 的完整重构版。重构重点不是换 API，而是把几类
容易混淆的东西显式分开：

- **编码**：位宽、固定位、实际字段绑定
- **操作数接口**：raw / rebuilt 的参数顺序
- **来源**：standard / `$import` / `$pseudo_op`
- **分组关系**：哪些 raw token 组成一个 rebuilt 逻辑操作数

---

## 快速开始

```bash
cd riscv-asm

# 生成 generated/
racket binary-build/main.rkt

# 构建 + 全部测试
make test
```

也可以只跑测试，但前提是 `generated/` 已经生成：

```bash
raco test test/*.rkt
```

当前结果：

```text
40161 tests passed
```

---

## 目录结构

```text
riscv-asm/
  riscv-opcodes/
    extensions/                 riscv-opcodes 扩展源文件

  binary-build/
    main.rkt                    构建入口
    config.rkt                  命令行选项
    paths.rkt                   输入/输出路径与 require 路径策略
    model.rkt                   解析数据结构、candidate、resolved-def

    parse.rkt                   源文件解析
    fixed.rkt                   固定字段取位（resolve / width 共用）
    resolve.rkt                 $import / $pseudo_op / 同名合并
    parcel.rkt                  指令长度规则
    layout/
      modules.rkt               raw/rebuilt 字段模块注册表
      groups.rkt                唯一的分组注册表
      plan.rkt                  raw / rebuilt operand plan
    emit/
      render.rkt                Racket 模块渲染
      fields.rkt                从 groups 生成 rebuilt 字段模块
      instruction.rkt           生成 raw / rebuilt 指令模块
      metadata.rkt              生成 instruction-info
      package.rkt               构建编排、清理、复制运行时模块

    runtime/lib/                原样复制到 generated/lib
      base.rkt
      bit.rkt
      limits.rkt                目标位索引上限
      layout-spec.rkt           相对路径段与文件名契约
      layout.rkt                运行时生成包布局（唯一来源）
      instruction_paths.rkt     指令路径 API
      riscv/raw/                手写 raw 字段布局
      info/
        struct.rkt              instruction-info / instruction-origin
        query.rkt               metadata 查询与规范化签名
        lookup.rkt              按扩展查表、消歧

  test/                         测试
  generated/                    构建输出（已生成）
    lib/                        运行时模块
    gen/                        生成的字段/指令/metadata
  DESIGN.md                     设计说明与操作点
```

---

## 构建选项

```bash
racket binary-build/main.rkt
racket binary-build/main.rkt --opcodes /path/to/riscv-opcodes/extensions
racket binary-build/main.rkt --output /tmp/riscv-asm-generated
racket binary-build/main.rkt --clean
racket binary-build/main.rkt --help
```

默认：

```text
opcodes: riscv-asm/riscv-opcodes/extensions
output:  riscv-asm/generated
```

构建会：

1. 读取 `extensions/` 顶层 ratified 文件
2. 解析 `$import` / `$pseudo_op`
3. 按优先级选择同名定义
4. 清理输出并复制运行时 `lib/`
5. 生成 rebuilt 字段模块
6. 生成 raw / rebuilt 指令模块
7. 生成 instruction metadata
8. 生成扩展清单和反向索引

---

## 构造流

整个构建过程严格分成四段，前一段完成后才进入下一段：

```text
来源
  binary-build/paths.rkt       源目录发现、扩展文件发现
  binary-build/config.rkt      CLI 覆盖
        |
        v
拆分处理
  binary-build/parse.rkt       源文件 -> instruction-def / pseudo-def / import-def
  binary-build/layout/groups   raw token -> 逻辑操作数分组
  binary-build/layout/plan     instruction-def -> raw / rebuilt operand plan
        |
        v
合并
  binary-build/resolve.rkt     standard / import / pseudo 候选 -> resolved-def
        |
        v
输出
  binary-build/emit/*.rkt      raw / rebuilt / metadata / rebuilt fields
  binary-build/paths.rkt       输出路径与 require 路径
```

`binary-build/emit/package.rkt` 会先完成全部解析和合并，再清理和写入输出；
源文件有错误时不会留下半成品 `generated/`。

## 常量与约束归属

| 类别 | 唯一维护点 | 说明 |
| --- | --- | --- |
| 生成包内相对路径段 / 文件名 | `binary-build/runtime/lib/layout-spec.rkt` | build-time 和 runtime 共用 |
| build-time 源目录 / 输出根 / 绝对路径 | `binary-build/paths.rkt` | `config.rkt` 的默认值也来自这里 |
| 源扩展文件前缀 | `binary-build/paths.rkt` | 当前是 `rv` |
| raw/rebuilt 字段模块注册表 | `binary-build/layout/modules.rkt` | build 会校验它和实际 `raw/*.rkt` 文件一致 |
| 逻辑操作数分组 | `binary-build/layout/groups.rkt` | 启动时会校验 group 的 module 名已注册 |
| raw 位布局 / 范围 / 对齐 | `binary-build/runtime/lib/riscv/raw/*.rkt` | 手写唯一来源 |
| 固定字段取位 | `binary-build/fixed.rkt` | resolve 和 width 计算共用 |
| 目标位索引上限 | `binary-build/runtime/lib/limits.rkt` | `model.rkt` 和 `bit.rkt` 共用 |
| 指令位宽规则 | `binary-build/parcel.rkt` | 16/32 与拒绝 48+ |
| extension 文件名 / info 变量名 | `layout-spec.rkt` | `<ext>.rkt`、`<ext>-instructions` |
| rv32/rv64 前缀 | `runtime/lib/info/lookup.rkt` | 本地常量 |

`origin` 的 `'standard / 'import / 'pseudo` 是一个小的封闭协议，定义在
`info/struct.rkt`，由 `resolve.rkt` 和 `lookup.rkt` 使用；它不是路径常量。

当前统计：

```text
ratified extensions: 110
standard definitions: 891
pseudo definitions:   189
import definitions:   155
emitted definitions:  1232
skipped duplicates:   3
```

跳过项：

```text
jal:  overridden-by-standard-definition
jalr: overridden-by-standard-definition
ld:   not-a-standard-form
```

---

## 设计要点

### 1. 分组关系只有一个来源

`binary-build/layout/groups.rkt` 同时驱动：

- `binary-build/layout/plan.rkt` 的 raw/rebuilt operand plan
- `binary-build/emit/fields.rkt` 的 rebuilt 字段模块生成
- metadata 中的 rebuilt 绑定

不再出现“手写 rebuilt 模块 + codegen 里再写一份 grouping 表”的重复。

新增一个逻辑操作数分组，例如：

```racket
(operand-group "c_uimm8" 'compressed '("c_uimm8lo" "c_uimm8hi"))
```

只需要改 `groups.rkt`。rebuilt 字段模块会自动生成。

### 2. raw 字段布局仍然是手写的

`binary-build/runtime/lib/riscv/raw/*.rkt` 是唯一的位布局来源。

这些字段包含不规则 bit-map、范围、对齐、压缩寄存器偏移等复杂规则，
不尝试从 token 名自动推断。新增字段时直接在这里显式写。

### 3. 编码签名与操作数接口分开

运行时 `generated/lib/info/query.rkt` 提供三组不同签名：

```racket
(instruction-info-encoding-signature info)
;; width + 规范化固定位 + raw 字段绑定 + rebuilt 字段绑定

(instruction-info-interface-signature info)
;; operands 顺序 + raw-operands 顺序 + 规范化 aliases

(instruction-info-provenance-signature info)
;; standard / import / pseudo + 来源扩展 + 来源指令
```

关键点：

- 固定字段按实际生成语义合并成 fixed word，所以字段顺序/切分不同不影响比较
- raw/rebuilt 绑定按集合比较，因为 `make-instruction` 是按位 OR
- `operands` / `raw-operands` 的顺序保留，因为参数顺序是公开接口
- `asm`、`size`、`name`、`extension` 不参与编码签名
- provenance 不参与编码签名

### 4. `$import` 和 `$pseudo_op` 显式保留来源

`instruction-info` 的 `origin` 字段：

```racket
(instruction-origin 'standard #f #f)
(instruction-origin 'import 'rv_zbb 'andn)
(instruction-origin 'pseudo 'rv64_i 'ld)
```

例子：

- `andn`：`rv_zbb` 是 standard，`rv_zbkb` 是 import → 编码相同，provenance 不同
- `zip`：`rv32_zbkb` 是 standard，`rv32_zk` 是 pseudo → 编码相同，provenance 不同
- `rv32_i` 的 `slli`：pseudo，来源 `rv64_i::slli`，但使用 `shamtw`，编码与 RV64 standard 不同

`resolve-instruction-info` 只在编码和接口都相同时去重；provenance 不导致冲突。
同编码时优先返回 standard，其次 import，最后 pseudo。

### 5. rv32/rv64 混用显式报错

`resolve-instruction-info` 会在查表前拒绝同时包含 `rv32_*` 和 `rv64_*` 的扩展集合。
不再依赖“签名不同才报错”来间接发现 XLEN 混用。

### 6. 不生成跨扩展总表

查表必须先给扩展集合：

```racket
(require "generated/lib/instruction_paths.rkt"
         "generated/lib/info/struct.rkt"
         "generated/lib/info/query.rkt"
         "generated/lib/info/lookup.rkt")

(define info
  (resolve-instruction-info '(rv_i rv_m) 'add))
```

同名指令在不同扩展下可能是不同变体，不能隐式全包搜索。

---

## 运行时 API

### 指令模块路径

```racket
(raw-instruction-path 'rv_i)
(rebuilt-instruction-path 'rv_i)
```

### metadata 查表

```racket
(instruction-info-extensions)
;; => '(rv32_c rv32_c_f ... rv_zvksh)

(instruction-info-path 'rv_i)
(extension-instruction-info 'rv_i)
(find-extension-instruction-info 'rv_i 'add)

(instruction-info-candidates '(rv_zbb rv_zbkb) 'andn)
(resolve-instruction-info '(rv_zbb rv_zbkb) 'andn)
```

### metadata 访问

```racket
(instruction-info-name info)
(instruction-info-extension info)
(info-kind info)
(info-source-extension info)
(info-source-instruction info)
(info-raw-bindings info)
(info-rebuilt-bindings info)
```

---

## 操作点

| 想改什么 | 改哪里 |
| --- | --- |
| 新增 raw 位布局/字段 | `binary-build/runtime/lib/riscv/raw/*.rkt` |
| 新增 raw 字段模块（新的 kind） | `binary-build/layout/modules.rkt` + `runtime/lib/riscv/raw/<file>.rkt` |
| 新增 rebuilt 逻辑分组 | `binary-build/layout/groups.rkt` |
| 改源文件语法 | `binary-build/parse.rkt` |
| 改 import/pseudo 优先级或冲突策略 | `binary-build/resolve.rkt` |
| 改 raw/rebuilt 参数生成 | `binary-build/layout/plan.rkt`、`binary-build/emit/instruction.rkt` |
| 改 metadata 字段 | `binary-build/runtime/lib/info/struct.rkt`、`binary-build/emit/metadata.rkt` |
| 改查表/消歧规则 | `binary-build/runtime/lib/info/lookup.rkt`、`query.rkt` |
| 改构建输出目录布局 | `binary-build/runtime/lib/layout-spec.rkt`、`binary-build/paths.rkt`、`binary-build/emit/package.rkt` |
| 改运行时生成包布局 | `binary-build/runtime/lib/layout-spec.rkt`、`binary-build/runtime/lib/layout.rkt` |
| 改命令行选项 | `binary-build/config.rkt` |
| 改构建阶段/清理策略 | `binary-build/emit/package.rkt` |

新增 raw 字段后，通常还要在 `test/field-ranges.rkt` 加范围，并重新构建测试。

---

## 测试

```bash
make test
```

测试覆盖：

- 每条 generated 指令、每个操作数的合法/越界/未对齐值
- parcel 长度规则
- metadata `size == width / 8`
- 扩展清单、反向索引、查表缓存
- encoding/interface/provenance 签名
- 固定字段顺序/切分规范化
- alias/binding 顺序无关
- rv32/rv64 混用报错
- 构建审计：源解析/解析结果 vs generated info vs raw/rebuilt 导出
- 已知跳过项

---

## 已知边界

- 只处理 `extensions/` 顶层 ratified 扩展；`unratified/` 不参与生成。
- 只支持 ≤32 位编码；48 位及以上由 `parcel.rkt` 拒绝。
- raw 字段布局是手写的，不从 `arg_lut.csv` 自动推导。
- rebuilt 分组是手写注册表，不根据 token 名猜测 hi/lo 关系。
- `$import` 当前只能导入源扩展的 standard 定义；`$pseudo_op` 的源也必须是 standard。
- 同优先级同名定义会直接报错，不静默取第一条。
