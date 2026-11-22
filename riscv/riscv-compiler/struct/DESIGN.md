# expand-struct（`struct.rkt`）

完整语法、布局规则和导出形状见 [`../STRUCT.md`](../STRUCT.md)。

## 作用

前端结构体布局层：

- 收集 `(struct (name-chain) ...)` 定义（名字和 label 一样是链）
- 计算字段 offset / size / align
- 处理内部 `(align n)` 和 `(pad n)` 空洞
- 展开 `(struct-data ...)` 为 `align` / `pad` / `value`
- 展开 `(struct-load ...)` / `(struct-store ...)` / `(struct-address ...)`
- 展开 `(sizeof ...)` / `(offsetof ...)`
- 产出最终 `build` 里的 `structs` 元数据

## 位置

```text
program-items + rich-data
  -> expand-struct
  -> expand-data
  -> flatten
  -> analyze
  ...
```

必须在 `layout` 之前，因为它会改数据尺寸并生成新的 code item；它不依赖最终地址。

## 边界

- 不做段保护 / 地址绑定 / 重定位。
- 不自动选择 short/far load/store：超范围报错，前端显式写 `*-far`。
- 不处理 bitfield / union / packed / 跨模块 struct 导入。
- 不自动给裸 `b32` / `b64` 数据加自然对齐；`struct-data` 自己负责布局。
