# link：外部符号、relocation、address data

外部源码和地址数据是分开的：

```text
build source       -> 本地 func / data / raw unit
interface source   -> extern 表（名字 + kind）
address data       -> link 时才用的 symbol -> address
```

## 1. extern

interface source 仍然按 module 规则解析，但不产生 unit。

输出：

```scheme
(extern (lib f) (kind func))
(extern (d table) (kind data))
```

kind：

- `func`
- `data`
- `raw`
- `raw-label`
- `data-label`

规则：

- build source 已定义的名字不再进入 extern
- build source 和 interface source 同名全局定义 -> frontend 报错
- extern 名不能和本地 func / raw / data / label 重名
- external call 只能指向 `kind func`
- external addr / data value 可以指向地址类 kind

## 2. address data

```scheme
(address (lib f) #x2000)
(address (d table) #x3000)
```

address data 只提供地址，不提供 kind。  
kind 只来自 interface source。

## 3. relocation

encode 输出：

```scheme
(relocation
  section
  offset
  kind
  symbol
  addend
  width
  reg)
```

第一版 kind：

| kind | 用途 | 尺寸 |
| --- | --- | --- |
| `call-pcrel` | 外部调用 | 8 |
| `addr-pcrel` | 外部地址 | 8 |
| `abs` | data 绝对地址初值 | 4 / 8 |

外部调用和外部地址都使用固定 8 字节形式，不在这里按距离选近/远：

```scheme
auipc x1, 0
jalr  x1, x1, 0
```

```scheme
auipc dst, 0
addi  dst, dst, 0
```

link 时再根据 address data 回填。

## 4. 从 source 到最终 bytes

```text
build source + interface source
  -> frontend
  -> resolved items + externs
  -> machine pipeline
  -> program-layout
       - 本地符号：正常算地址
       - extern：placeholder + relocation
  -> encode
       - bytes
       - relocations
  -> link(address data)
       - 检查 extern 是否都有地址
       - 检查 address data 是否有多余符号
       - 回填 relocation
```

## 5. 错误规则

- extern 没有 address，但被引用 -> unresolved
- address data 指向非 extern 符号 -> 报错
- address 重复 -> 报错
- external call 指向非 func -> 报错
- relocation 超出 `auipc+jalr` / `auipc+addi` 范围 -> 报错
- `abs` 超出宽度 -> 报错

## 6. 当前不做的

- object / ELF
- section 重排 / section GC
- linker relaxation / veneer
- 动态链接 / GOT / PLT
- 任意 64-bit 外部地址
- 外部符号地址在 compile 阶段提前解析
