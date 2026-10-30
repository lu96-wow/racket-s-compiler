# flatten（`flatten.rkt`）

## 作用

编译期纯名字解析：把 `module` / `provide` / `require` / `prefix-in` / `rename-in` / `rename-out`
展开成完整链。之后的层看不到模块系统。

## 相关 s-exp

| 输入 | 输出 |
| --- | --- |
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

## 边界

不处理伪指令、数据展开、段、偏移、尺寸。
