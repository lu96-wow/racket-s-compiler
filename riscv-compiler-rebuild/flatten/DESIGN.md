# flatten 模块系统 + 链式查表（`flatten/flatten.rkt`）

> 只做**名字**，不做指令。把模块结构解析成完整链，之后的层看到的全是 `(模块… 名字)`。

## 1. 职责

| 做 | 不做 |
| --- | --- |
| `(module …)` 嵌套 → 完整链 | 认识任何助记符 |
| `provide` / `require` / `prefix-in` / `rename-in` / `rename-out` | 段 / 偏移 / 尺寸 |
| 建"完整链 → 位置"表 | 判断 item 是否合法 |
| 多输入共享一张名字表和模块表 | 改 item 的**形状**（只重写操作数里的链） |

## 2. 输入 / 输出

```racket
(flatten-inputs (list src1 src2 ...))
  -> (values (listof (listof item)) 名字表)     ; 名字表 = 完整链 -> 位置序号

(flatten-program items) -> (listof item)
(flatten-items items)   -> (values (listof (listof item)) 名字表)
```

旧壳 `(quote …)` / `(begin …)` 入口接受，出口一律 plain list。

## 3. 语法

```
(module 名
  (provide 链 ...                          ; 导出，外部名 = 本地名
           (rename-out (本地链 外部链) ...)  ; 导出时改名
           *)                              ; 本模块直接定义的 label（用它们的本地链）
  (require 模块链                          ; 拉进本模块作用域
           (prefix-in p: 模块链)            ; 绑成 p:名字
           (rename-in 模块链 (外部链 本地链) ...))  ; 导入时改名
  item ...)
```

`provide` / `require` 子句也可以写在**根**（没有 `module` 包裹的那一层 item 里）。

```racket
(module data
  (provide (rename-out ((d table) table)))
  (label d table)                    ; 内部名 (d table)
  (utf-stringz "hi"))

(module prog
  (require data)
  (la t0 (table)))                   ; 用短名；输出里是 (data d table)
```

## 4. 可见性规则

1. **默认私有**：没有 `provide` 的 label，模块外引用不到 —— 连写完整链也不行。
2. **label 在声明它的模块及其子模块里可见**（词法嵌套），内层遮蔽外层。
3. **`require` 绑定在本模块及其子模块里可见**，同样由内到外。
4. **解析顺序**（由内到外，每层先绑定再本地 label）：
   `require 绑定` → 本地 label（只认"祖先或自己"模块里定义的）。
5. **跨模块引用必须 `require`**；写全名不是后门。
6. `(provide *)` 导出的是**本模块直接定义**的 label（本地链），不含子模块的。
7. `provide` 的名字可以是 `require` 进来的（**re-export**），例如
   `(provide (rename-out ((f) ff)))`。
8. **`require` 允许成环**：这里只是名字解析，不涉及初始化顺序（数据 ↔ 代码 就是这样）。
   环里只要有一条 base（本模块自己的 label），就能解出来。

## 5. 报错

| 情况 | 报什么 |
| --- | --- |
| 引用私有/不存在的名字 | `undefined label (a g) (module (b))` |
| 本模块 label 与 require 进来的名字同名 | `module (b): (f) is both defined here and required` |
| 两个 require 给同一个短名但指向不同目标 | `module (c): (f) is required from two places (…)` |
| `provide` 了一个不存在的东西 | `module (a) provides (nope), but it is not defined there` |
| `require` 不存在的模块 | `undefined module (ghost) (known: …)` |
| 模块重名 | `module (a) is defined twice` |
| 同一条链在两个位置 | `label (a f) is defined in two places` |
| require 环里没有 base，`provide` 解不出来 | `module (a) provides (fa), but it is not defined there` |

`provide` 的校验是**主动**的：不用等别人 require 到它才发现。

## 6. 实现（四步）

| 步 | 做什么 |
| --- | --- |
| 1 `annotate` | 递归模块，给每个 item 标 scope，登记模块（provides / requires / own-labels） |
| 2 `index-labels!` | 完整链 → `(slot . 声明模块)`；slot = 连续 label 组；顺便记下"哪些 label 属于哪个模块" |
| 3 `resolve-modules!` | 不动点：`imports` 由对方 `provides` 算，`provides` 又可能依赖自己的 `imports`（re-export）；收敛后统一校验 |
| 4 `resolve-items` | 把每个 item 的引用换成完整链（label 也换） |

同一个位置可以有多个名字：连续写多条 `(label a f)` / `(label a g)`。

## 7. 不归本层管

- 指令拼写、伪指令展开（expand-pseudo）。
- 段、地址、尺寸（layout）。
- `(module …)` 里的**数据展开**（expand-data 会把壳递归展开、壳留着）。
- 运行时：模块系统是**编译期纯名字解析**，不产生 GOT / 间接跳转之类的东西。

## 8. 测试（`flatten/test.rkt`，65 条）

嵌套与遮蔽、跨输入共享、`provide` / `require` / `prefix-in` / `rename-in` / `rename-out` /
`(provide *)` / re-export、多 require 叠加、私有性、七类报错、循环 require（合法与无 base）、
地址表达式（`(ref 链 加数)`，形状判定在 `sexp.rkt`）里的链、压缩指令不动、幂等。

## 9. 已知缺口

- 没有 `only-in` / `except-in` / `all-from-out` / 条件 require。
- `prefix-in` 只给**链的头**加前缀（`(d table)` → `(dt:d table)`）；Racket 里名字是单个符号。
- 模块只按名字引用，没有"文件路径"概念（模块可以分散在不同输入里，靠名字连起来）。
