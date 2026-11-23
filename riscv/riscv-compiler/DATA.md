# 数据形状与解析入口

> 这份表回答两件事：每一层吃什么、吐什么；同一种 s-exp 形状只由谁解析。

## 1. 通用层

| 文件 | 负责 | 不负责 |
| --- | --- | --- |
| `sexp.rkt` | `form?` / `name?` / `path?` / `normalize-path`；数据 item；地址表达式 | 模块、struct、指令 |
| `meta.rkt` | 带标签元数据的读取：`(tag (key value) …)` 的 `tagged-form?` / `tag-ref` / `tag-ref*` | 某个具体元数据的语义 |
| `modules.rkt` | 模块树、`provide` / `require` / `prefix-in` / `rename-in` / `rename-out`、re-export、provides 元数据 | label / struct 自己的声明 |
| `struct-meta.rkt` | struct 元数据 ↔ 内部 `sdef`；`sdef` → 布局无关声明 | struct 布局计算、字段访问展开 |
| `target.rkt` | XLEN、扩展、端序、整数 → 字节 | 名字解析 |

## 2. stage 输入 / 输出

| stage | 输入（在途值） | 输出（在途值） |
| --- | --- | --- |
| `load-units` | 可选 `extern-units`；以及旧的 `extern-structs` / `extern-struct-provides` / `extern-label-provides` | `extern-structs` `extern-struct-provides` `extern-label-provides` |
| `expand-struct` | `program-items` `rich-data`；可选 `extern-structs` `extern-struct-provides` | `program-items` `rich-data` `structs` `struct-provides` |
| `expand-data` | `rich-data` | `data-items` |
| `flatten` | `program-items` `data-items`；可选 `externs` `struct-provides` `extern-label-provides` | `program-items` `data-items` `names` `exports` `label-provides` `module-requires` |
| `analyze` | `program-items` `data-items` | `program` |
| `dce` | `program` | `program` |
| `emit-unit` | `program` `data-items`；可选 `structs` `label-provides` `struct-provides` `module-requires` | `unit` |
| `layout` | `program` `data-items` `layout-spec`；可选 `externs` | `measured-layout` |
| `check` | `measured-layout` | `measured-layout`（追加 problems） |
| `bind-labels` | `measured-layout`；可选 `exports` | `bound-layout` |
| `encode` | `bound-layout`；可选 `structs` `label-provides` `struct-provides` `unit` | `build`（布局镜像） |
| `emit-program` | `build` `program` `data-items`；可选 `unit` `extern-units` `externs` | `program`（最终 s-exp） |

## 3. 名字 / 可见性

### 3.1 label

```scheme
(label 链 …)                    ; 一个位置可以有多个名字
```

- 身份：完整链，例如 `(a f)`。
- 可见性：`label-provides`。
- 类型：`function` / `data` / `unknown`。

### 3.2 struct

```scheme
(struct 链 (field type) … (align n) (pad n) …)
(struct-data 链 (field value …) …)
```

- 身份：完整链 + struct 名字空间。
- 可见性：`struct-provides`。
- 布局结果：`structs` 元数据里的 `size` / `offset` / `align`。

### 3.3 provides 元数据

```scheme
(label-provides
  (module (a)
    (provide (f) (a f))
    (provide (out) (a f))))

(struct-provides
  (module (a)
    (provide (point) (a point))))
```

- 一列是**外部名**，二列是**绝对身份**。
- `modules.rkt` 负责生成和解析这个形状。

## 4. struct 元数据

### 4.1 布局结果

```scheme
(struct-def
  (name (a point))
  (size 16)
  (align 8)
  (fields
    (field (name x) (type b32) (offset 0) (size 4) (align 4)))
  (padding
    (align (n 8) (offset 4) (size 4))))
```

由 `struct-meta.rkt` 解析/打印：

- `parse-sdef`
- `sdef->sexp`
- `sdef->decl`

### 4.2 布局无关声明

```scheme
(struct (a point)
  (x b32)
  (align 8))
```

`unit` 使用这一种；它没有 `offset` / `size`，重新编译时再按目标 ABI 计算。

## 5. unit：布局前接口

```scheme
(unit
  (format 1)
  (target rv64)
  (modules
    (module (a)
      (provide (label (f) (a f) function))
      (provide (struct (point) (a point)))))
  (declarations
    (label (a f) function)
    (struct (a point) (x b32) (y b32))))
```

不包含：

- 绝对地址
- `offset` / `size`
- segment 字节

`unit.rkt` 的输入是已经 flatten 的程序 / 数据、`structs`、`label-provides`、`struct-provides`；它不重新做布局。

`load-units` 是反向方向：把上一个编译单元的 `unit` 转成当前流水线认识的
`extern-structs` / `extern-struct-provides` / `extern-label-provides`。
struct 声明会在这一步按当前 target 重新算 offset/size。

## 6. 布局与镜像

### 6.1 layout-spec

```scheme
((origin #x80000000)
 (segments (segment (name c) (kind code) (start #x80001000) (end #x80002000) (align 4)))
 (place c (a f) (a g)))
```

- `layout/layout.rkt` 解析。

### 6.2 measured / bound

```scheme
((phase measured)
 (segments …)
 (anchors (anchor 链 段名 偏移) …)
 (problems …))

((phase bound)
 (segments …)
 (anchors …)
 (symbols (symbol 链 段名 偏移 地址) …)
 (link (base B) (symbol 链 地址) …)
 (provides 链 …)
 (problems …))
```

- `layout` / `check` / `bind-labels` 各自读取自己需要的部分。
- segment 字段统一通过 `meta.rkt` 的 `tag-ref` / `tag-ref*` 读取。

## 6.3 program：最终对外形状

```scheme
(program
  (internal
    (modules
      (module main
        (base #x80000000)
        (require ...)
        (provide ...)))
    (rich-data ...)
    (functions ...)
    (offsets
      (offset (main f) #x1000)
      (offset (main table) #x2000)))
  (external
    (modules
      (module lib
        (base #x80100000)
        (provide ...)))
    (rich-data ...)
    (functions ...)
    (offsets
      (offset (lib g) #x100))))
```

- `internal.modules` 是一个根 module（一个项目一个根）；多个顶层 module 时根是 `(module ())`。
- `external.modules` 每个外部项目一个根 module；`require` 写在 module 里，不需要 `project-require`。
- **base 是项目根 module 的属性**。
- **offsets 里是相对该项目 base 的偏移**。
- 绝对地址 = 项目根 module 的 `base` + `offsets` 里的偏移。
- `internal.modules` 是 `provide` / `require` 的唯一来源。
- 数据对象是 `(data (链 ...) item ...)`；函数是 `(function (链 ...) (body item ...))`。

### 6.4 build（布局镜像）

```scheme
(build
  (link (base B) (symbol 链 地址) …)
  (provides 链 …)
  (structs (struct-def …) …)
  (label-provides …)
  (struct-provides …)
  (unit …)
  (segment (name …) (kind …) (start …) (size …) (bytes #vu8…)) …)
```

- `link` / `provides` / `segment` 是最终镜像。
- `label-provides` / `struct-provides` / `structs` / `unit` 是接口元数据。
- `provides` 是 link-file 的便捷投影；完整可见性在 `label-provides`。

## 7. 已合并的重复逻辑

| 以前分散在 | 现在 |
| --- | --- |
| `flatten` / `struct` / `unit` 各写一遍 module provide/require 解析 | `modules.rkt` |
| `flatten` / `struct` 各写一遍 `chain-of` / `chain<?` | `modules.rkt` |
| `struct` / `unit` 各写一遍 struct-def / field / padding 解析 | `struct-meta.rkt` |
| `struct` / `unit` 各写一遍 `type->sexp` / `type->source` | `struct-meta.rkt` |
| `bind-labels` / `check` / `encode` / `layout` 各写一遍 segment 字段读取 | `meta.rkt` 的 `tag-ref` / `tag-ref*` |
| 多层各写 `(assoc tag (cdr form))` + 长度检查 | `meta.rkt` |

## 8. 刻意不合并的部分

| 形状 | 原因 |
| --- | --- |
| `riscv-asm` 的 instruction-info | 编码事实只应有一个来源；不跟本目录的数据形状耦合 |
| rich 数据（`b8` / `utf-string` / `bN-array`） | 属于 `expand-data` 的输入语言 |
| layout spec（`segment` / `place`） | 属于布局策略，不是名字元数据 |
| `build` 的 segment 字节 | 属于最终镜像，不是接口 |
