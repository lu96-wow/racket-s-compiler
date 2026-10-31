# amd64-help

## 作用

放 amd64 编译器需要的辅助函数：常量/地址装载规则、范围判断等。
这些函数不编码字节、不做布局，也不属于 amd64-asm。

## 相关 s-exp

| 文件 | 输入 | 输出 |
| --- | --- | --- |
| `li.rkt` | `(li dst 整数/地址表达式)` | `(mov dst 整数)` 或 `(lea dst (b64 (base rip) (disp 表达式)))` |
| `ranges.rkt` | 整数 + 目标范围 | 布尔值 |

## 设计思路

- `li.rkt` 只负责“li 展开成什么 form”，不判断标签距离；距离由 layout 检查。
- `ranges.rkt` 只放纯整数谓词，供 layout / bind-labels 使用，避免各层各写一份
  `(expt 2 31)`。
- 编译器层依赖本层；本层不依赖 layout/encode/flow。

## 边界

- 不编码指令。
- 不做布局、不做松弛、不绑符号。
- 不处理 far form / scratch；这些是 amd64-asm 的编码能力。
