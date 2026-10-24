# riscv-help 设计指导书

本文是 `riscv-help` 的维护说明，记录当前 API、加载形式、范围、自动分派规则、已知限制和后续扩展点。

当前阶段只做**已知数值的指令展开**，不包含 label、reloc、布局或链接松弛。

---

## 1. 目标与边界

`riscv-help` 负责把“想做的操作”展开成 RISC-V 指令列表：

```racket
(mnemonic operand ...)
```

当前覆盖：

- 常量 / 绝对地址加载：`li`
- PC 相对地址加载：`load-pcrel`
- 基础 `la` 形式：`la-pcrel`、`la-abs`、`la-got`、`la-gp`、`la-frame`
- 跳转：`jump-*`
- 条件分支：`branch-*`
- 范围判别、hi/lo 拆分、寄存器名和 scratch 规则

当前不覆盖：

- 未解析符号
- label 定义 / label 引用
- relocation IR
- 地址布局
- 链接松弛
- GOT / TLS 的真实重定位生成
- 压缩指令选择
- 最终机器码编码

这些内容需要后续单独设计，不应塞进当前展开层。

---

## 2. 文件职责

| 文件 | 职责 |
| --- | --- |
| `ranges.rkt` | 纯数值范围判断、符号扩展、hi/lo 拆分 |
| `registers.rkt` | 转发 `riscv-asm/base/register.rkt`，统一寄存器表示 |
| `scratch.rkt` | scratch 参数规范化、非零检查、重复检查 |
| `li.rkt` | 常量 / 绝对地址加载，自动分派，`li` / `li-size` |
| `la.rkt` | PC 相对地址、绝对地址、GOT 占位、gp/frame 相对地址 |
| `jump.rkt` | 跳转展开 |
| `branch.rkt` | 条件分支展开 |
| `compose.rkt` | 聚合导出 |
| `test/` | `li`、`la` 的回归测试 |

不要在 `li.rkt` / `la.rkt` 里重新维护寄存器表。
寄存器唯一来源是 `riscv-asm/base/register.rkt`。

---

## 3. 基本表示

### 3.1 指令

指令统一是 list：

```racket
(mnemonic arg ...)
```

例如：

```racket
(addi a0 a0 8)
(lui a0 524288)
(auipc a0 0)
```

约定：

- `mnemonic` 是 symbol
- `c.*` 视为 2 字节，其余视为 4 字节
- 当前 `li` / `load-pcrel` 生成的都是 4 字节非压缩指令
- 没有 label / reloc 操作数

### 3.2 寄存器

寄存器入口是：

```racket
(require "registers.rkt")
```

支持三种输入：

```text
整数 0..31
'x0 .. 'x31
'zero / 'ra / 'sp / 'a0 / 'fp ...
```

查询函数：

```racket
register?
register->number
register-x-name
register-abi-name
register-abi-names
same-register?
zero-register?
nonzero-register?
compressed-prime-register?
compressed-branch-register?
```

### 3.3 scratch

`scratch.rkt` 负责：

```racket
scratch-list
take-scratch!
check-distinct!
check-not-zero!
```

规则：

- scratch 不能是 `x0`
- 需要多个 scratch 时必须互不相同
- 某些展开要求 scratch 不能等于目标寄存器
- 没有 scratch 时，不能偷偷生成错误代码，必须报错

### 3.4 word size

所有地址/常量入口都带：

```racket
#:word-size 'rv32 | 'rv64
```

默认是 `'rv64`。

---

## 4. API 分层

### 4.1 推荐入口

调用方通常只用四个：

```racket
(li rd value
    #:word-size 'rv32|'rv64)

(li-size value
         #:word-size 'rv32|'rv64)

(load-pcrel rd delta
            #:word-size 'rv32|'rv64
            #:scratch scratch)

(load-pcrel-size delta
                 #:word-size 'rv32|'rv64
                 #:scratch scratch)
```

语义：

- `li`：加载常量或绝对地址
- `load-pcrel`：加载 `address(AUIPC) + delta`
- `li-size`：返回 `li` 展开后的字节数
- `load-pcrel-size`：返回 `load-pcrel` 展开后的字节数

### 4.2 低层入口

这些入口保留，供需要明确控制形式时使用：

```racket
li-s12
li-lui
li-lui-addi
li-lui-addiw
li-zext32
li-low32-zero
li-general64
expand-li

la-pcrel
la-abs
la-got
la-gp
la-frame
expand-la
```

低层入口是**严格叶子函数**：范围不满足直接报错，不自动回退。

高层入口负责自动分派。

### 4.3 兼容入口

`expand-la` 仍然保留：

```racket
(expand-la rd value
           #:mode 'pcrel|'abs|'got|'gp|'frame
           #:word-size ...
           #:scratch ...
           #:base ...)
```

它只是分派器，不承担新的标签/重定位语义。

---

## 5. 加载形式状态表

### 5.1 `li`：常量 / 绝对地址

| 形式 | API | 指令 | 范围 | 大小 |
| --- | --- | --- | --- | --- |
| s12 | `li-s12` | `addi rd, x0, imm12` | `[-2048, 2047]` | 4B |
| LUI | `li-lui` | `lui rd, hi20` | RV32：低 12 位为 0 的 32 位值；RV64：`[-2^31, 2^31-4096]` 内 4096 的倍数 | 4B |
| LUI+ADDI | `li-lui-addi` | `lui` + `addi` | RV32：任意 32 位模式；RV64：`[-2^31-2048, 2^31-2049]` | 4B / 8B |
| LUI+ADDIW | `li-lui-addiw` | `lui` + `addiw` | RV64 only：signed-32 `[-2^31, 2^31-1]` | 4B / 8B |
| zext32 | `li-zext32` | 32 位加载 + `slli 32` + `srli 32` | RV64：`[2^31-2048, 2^32-1]` | 12B / 16B |
| low32-zero | `li-low32-zero` | `li32(high32)` + `slli 32` | RV64：low32 为 0，即 `k << 32` | 8B / 12B |
| general64 | `li-general64` | GAS 风格 shift 递归 | RV64：任意 64 位模式 | 最坏 8 条，32B |

### 5.2 `load-pcrel`：PC 相对地址

定义：

```text
delta = target - address(AUIPC)
```

`AUIPC` 始终是展开结果的第一条指令，因此 `delta` 相对于展开起点。

| 情况 | 形式 | 范围 | 大小 |
| --- | --- | --- | --- |
| 近 | `auipc` + `addi` | RV64：`[-2^31-2048, 2^31-2049]`；RV32：32 位偏移 | 8B |
| RV64 远 | `auipc rd,0` + `li temp,delta` + `add` | 任意 64 位 delta，需要 scratch | `li-size(delta) + 8B` |
| RV32 超范围 | 报错 | 没有 far 形式 | - |

### 5.3 `la` 其他形式

| API | 形式 | 范围 | 大小 | 状态 |
| --- | --- | --- | --- | --- |
| `la-pcrel #:delta d` | `auipc` + `addi` | 同上近范围 | 8B | 可用 |
| `la-pcrel` 无 delta | `auipc rd,0` + `addi rd,rd,0` | 不判别 | 8B | 占位，不是最终代码 |
| `load-pcrel` | 自动近/远 | 见上 | 8B 或 `li-size+8B` | 可用 |
| `la-abs` | 复用 `expand-li` | 同 `li` | 同 `li` | 可用 |
| `la-got` | `auipc rd,0` + `lw/ld rd,rd,0` | 不判别 | 8B | 占位 |
| `la-gp` | `addi rd, gp, off` | `[-2048, 2047]` | 4B | 可用 |
| `la-frame` 小 offset | `addi rd, base, off` | `[-2048, 2047]` | 4B | 可用 |
| `la-frame` 大 offset | `li tmp, off` + `add rd, base, tmp` | offset 同 `li` | `li-size+4B` | 可用，需要 scratch |

### 5.4 跳转 / 分支范围

| 形式 | 范围 | 备注 |
| --- | --- | --- |
| `c.j` / `c.jal` | ±2KiB，偶数 | `c.jal` 仅 RV32 |
| `jal` | ±1MiB，偶数 | |
| `auipc + jalr` | 约 ±2GiB | |
| `jalr` | imm12 `[-2048, 2047]` | |
| B-type branch | ±4KiB，偶数 | |
| `c.beqz` / `c.bnez` | ±256B，偶数 | rs1 限制 x8..x15 |
| `branch-long` | inverse branch skip 必须能放进 B-type | jump 序列由调用方提供 |
| `jump-abs` | target 范围同 `li` | 需要 scratch |
| `jump-pcrel-far` | RV64，任意 64 位 offset | 需要 scratch，RV32 报错 |

---

## 6. 自动分派规则

### 6.1 `li`

#### RV32

```text
fits-s12?
  -> addi

low12 == 0
  -> lui

否则
  -> lui + addi
```

RV32 覆盖整个 32 位值域。

#### RV64

按顺序判断：

```text
1. s12
2. LUI / LUI+ADDI 精确可表示
3. signed-32 但 LUI+ADDI 不精确 -> LUI+ADDIW
4. zext32 窗口
5. low32 为 0
6. 任意 64 位 -> general64
```

关键点：

- `LUI` 在 RV64 会符号扩展到 64 位
- 因此 `LUI+ADDI` 不是整个 signed-32
- `0x7fffffff` 这类值必须用 `ADDIW` 修正
- 正整数 `2^31-2048 .. 2^32-1` 走 `zext32`
- `low32=0` 走 `slli 32`
- `general64` 用从低位到高位的 shift 递归

### 6.2 `load-pcrel`

```text
fits-auipc-pair?(delta, word-size)
  -> auipc + addi

否则 rv64:
  -> 需要 scratch
  -> auipc rd,0
     li temp,delta
     add rd,rd,temp

否则:
  -> 报错
```

注意事项：

- far 形式中 `AUIPC` 必须放第一条
- 如果先放 `li` 再放 `AUIPC`，`delta` 的基准会变化
- scratch 不能是 `x0`
- far 时 scratch 不能等于 `rd`
- 没有 scratch 时不能退回错误形式，必须报错

---

## 7. 典型场景与处理办法

| 场景 | 处理 |
| --- | --- |
| 常量在 `[-2048, 2047]` | `addi rd, x0, imm` |
| RV32 任意 32 位常量 | `lui` 或 `lui+addi` |
| RV64 `0x7fffffff` | `lui+addiw` |
| RV64 正整数 `2^31-2048 .. 2^32-1` | `zext32` |
| RV64 low32 为 0 | `slli 32` |
| RV64 任意 64 位常量 | `general64` |
| PC 相对 delta 在 ±2GiB 内 | `auipc+addi` |
| RV64 PC 相对 delta 超出 ±2GiB | `auipc+li+add`，需要 scratch |
| RV32 PC 相对 delta 超出 32 位 | 报错 |
| far 但没有 scratch | 报错 |
| far 且 scratch 等于 `rd` | 报错 |
| scratch 是 `x0` | 报错 |
| gp 相对 offset 超出 s12 | 报错 |
| frame offset 在 s12 内 | `addi rd,base,off` |
| frame offset 超出 s12 | `li tmp,off + add`，需要 scratch |
| 未解析符号 | 当前不支持；`la-pcrel #f` 只是占位 |
| GOT 地址 | 当前只有占位，不是真实 GOT 重定位 |
| 目标地址超出 AUIPC 范围 | 用 GOT、大代码模型或完整 64 位 `li`，当前 API 不自动跨代码模型 |

---

## 8. 不变量

维护时应保持：

1. `li` 和 `li-size` 使用同一套展开逻辑。
2. `load-pcrel` 和 `load-pcrel-size` 使用同一套近/远判断。
3. 低层叶子函数严格检查边界，不静默回退。
4. `load-pcrel` 的 `delta` 始终相对于 `AUIPC`，且 `AUIPC` 是第一条。
5. far 形式必须显式提供合法 scratch。
6. `la-pcrel #f` / `la-got` 只能作为占位，不能被当成最终正确代码。
7. 寄存器名只在 `riscv-asm/base/register.rkt` 维护。
8. 新增形式时，必须同时更新：
   - 范围判断
   - 自动分派
   - size 判断
   - 测试
   - 本文档

---

## 9. 已知限制

- 没有 label / reloc / layout。
- 未解析符号不能生成正确代码。
- `la-got` 只是占位，没有 GOT 重定位。
- 没有 TLS。
- 没有链接松弛：
  - 不会把 `auipc+addi` 改成 gp/x0 相对
  - 不会删除 AUIPC
- 没有压缩指令选择：
  - `li-size` / `load-pcrel-size` 计算的是当前展开的源指令大小
  - 不代表最终链接后的压缩/松弛结果
- `load-pcrel` 只接受数值 delta，不接受 `target + pc` 自动求差。
- RV32 没有 far PC 相对形式。
- `li` 的 `#:scratch` 目前不参与选择。
- `load-pcrel-size` 的 far 分支只检查 scratch 是否存在且非零，不检查 scratch 与最终 `rd` 是否冲突（size API 没有 `rd`）。

---

## 10. 维护操作点

| 想改什么 | 改哪里 |
| --- | --- |
| 常量加载形式选择 | `li.rkt` 的 `expand-li` |
| 新增常量叶子形式 | `li.rkt`，同时更新 `expand-li`、`li-size`、测试 |
| 范围判断 / hi-lo 拆分 | `ranges.rkt` |
| RV64 ADDIW 规则 | `ranges.rkt` 的 `fits-lui-addiw?`、`li.rkt` 的 `li-lui-addiw` |
| PC 相对近/远选择 | `la.rkt` 的 `load-pcrel` |
| PC 相对长度 | `la.rkt` 的 `load-pcrel-size` |
| 常量长度 | `li.rkt` 的 `li-size` |
| gp / frame 地址 | `la.rkt` |
| GOT 占位 | `la.rkt` 的 `la-got` |
| scratch 规则 | `scratch.rkt` |
| 寄存器名 | `riscv-asm/base/register.rkt` |
| 跳转范围 | `ranges.rkt`、`jump.rkt` |
| 分支范围 | `ranges.rkt`、`branch.rkt` |
| 测试 | `riscv-help/test/` |

---

## 11. 测试

运行：

```bash
raco test riscv-help/test/*.rkt
```

当前测试覆盖：

- `li` 的 RV32/RV64 展开
- `li-size` 与展开长度
- RV64 ADDIW
- zext32
- general64 随机 64 位值语义回归
- `load-pcrel` 近/远形式
- far scratch 缺失
- scratch 为 `x0`
- scratch 等于 `rd`
- RV32 超范围
- `load-pcrel-size` 与生成结果一致
- `la-pcrel`、`la-abs`、`la-gp`、`la-frame`、`expand-la` 基础行为

最近结果：

```text
1078 tests passed
```

---

## 12. 后续可能扩展

以下内容需要单独设计，不要直接混入当前展开层：

1. label / local symbol 表示
2. relocation 记录
3. 地址布局 pass
4. `auipc+addi` 的 hi/lo 配对
5. gp/x0 松弛
6. GOT / TLS
7. 压缩指令和最终长度计算
8. 大代码模型 / far call
9. `target + pc` 自动选择绝对或相对加载
10. `li-kind` / `load-pcrel-kind` 形式判别 API
