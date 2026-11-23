# flatten（`flatten.rkt`）

## 作用

编译期纯名字解析：把 `module` / `provide` / `require` / `prefix-in` / `rename-in` / `rename-out`
展开成完整链。之后的层看不到模块系统。

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
| `(provide …)` 子句 | 记进**导出集合**（第三个返回值） |
| `(module 名 item…)` | 去掉壳后的 item |
| `(provide …)` / `(require …)` | 消失（只影响名字可见性） |
| `(prefix-in p: 链…)` | 链的头一节加前缀 |
| `(rename-in ((旧 新) …))` / `(rename-out …)` | 改名后的完整链 |
| `(label 链…)` 和操作数里的链 | 完整链 |

## 设计思路

- 模块只影响名字，不影响指令、尺寸、地址，所以本层只做名字解析。
- 默认私有：跨模块引用必须 `require`，写全名不是后门。
- `provide` / `require` 可以成环；这里没有初始化顺序。
- 链是身份：`(label a f)` 是同一位置的多个名字；解析后所有层只认完整链。
- **外部符号**（输入侧 link 表里的名字）只在解析的最后一步兜底：本地/require 都
  解不到时，若 `ref` 正好在外部符号表里就原样返回（外部名字不套模块前缀）。
  于是笔误仍然报 `undefined label`，而真外部引用能过。
- 导出集合是产物的一部分：`flatten-inputs` 返回 `(values items names exports)`，
  `exports` 是各模块 `(provide …)` 的并集（**绝对链**，已去重排序），
  或 `'all`（全单元没有 provide 子句 = 平铺镜像语义，全导出）。
  它一路传到 `bind-labels`，最后成为产物的 `(provides 链 …)` 和 link 文件。
- 模块树、provide/require、prefix-in/rename-in/rename-out、re-export 的
  通用不动点在 [`../modules.rkt`](../modules.rkt)；本层只提供 label 声明表。
- `struct-provides` 是可选输入：struct 有独立名字空间；这里只跳过 struct-only
  provide，不让 label 层误报。
- `extern-label-provides` 提供上一份编译单元的模块导出表，使跨编译单元的
  `require` 也能绑定；地址仍然来自 `externs`。
- 产物多一个按模块的 `label-provides`，下一份编译可以把它当
  `extern-label-provides`。

## 边界

不处理伪指令、数据展开、段、偏移、尺寸。
