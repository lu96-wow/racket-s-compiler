# dce（`dce.rkt`）

## 作用

死代码消除。删不可达块、删“跳到紧邻下一块”的转移、空块并进下一块，跑到不动点。

## 相关 s-exp

输入和输出都是 `program`：

```racket
(struct program (blocks flows))
```

- `blocks`：`(block <头链列表> item…)`
- `flows`：`(flow (succ id…) (fallthrough id|#f) (root? bool))`

## 设计思路

- `blocks` 和 `flows` 是平行数据；任何变换都必须同时改两份并重映射 id。
- 只做三种保守变换：可达性、冗余转移、空块合并。
- 不造 label、不改 item 内容、不补跳。
- 远形式也按控制转移处理，所以 DCE 不关心松弛前后。

## 边界

不补 `broken-fallthrough`、不松弛、不算尺寸/地址、不重排。
