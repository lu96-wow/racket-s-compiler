# dce（`dce.rkt`）

## 作用

死代码消除。删不可达块、删“跳到紧邻下一块”的转移、空块并进下一块，跑到不动点。

删块时**自己检查依据**（`check-deletion-evidence!`）：一个块被判死，它的物理
前一块必然"不顺序落下"，那就用 `insn.rkt` 的 `non-fallthrough-reason` 重算一遍，
并且只接受 `(jump indirect ret ud2)`——这是和 `insn.rkt` 硬件名单**独立的第二张
表**：那边回答"这条指令凭什么不落下"，这边回答"删代码时我愿意接受哪几种"。
想给某条指令加"不落下"，两边都得改，改这边时必须先想清楚"删掉后面的代码会不会
出事"。依据不成立就报错拒绝删除，而不是静默删（参见 `hlt` 那次：`hlt` 被当成
终止指令，`syscall-hlt` 的队尾 `cli/swapgs/sysretq` 被删，醒来落进下一条
syscall 实现 → #GP → #DF）。

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
- 目前只有 short/near；如果以后加 far form，也按控制转移处理，DCE 不关心松弛前后。

## 边界

不补 `broken-fallthrough`、不松弛、不算尺寸/地址、不重排。
