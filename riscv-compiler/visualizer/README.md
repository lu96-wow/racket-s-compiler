# F-asm / call/cc 可视化

直接用浏览器打开：

```bash
firefox visualizer/index.html
# 或
xdg-open visualizer/index.html
```

## 场景

- `(+ 1 41)`：没有 continuation，`k` 一直是 `HALT`。
- `(+ 1 (call/cc ...))`：看到 `C1` 出现、被复制进 `argv`、被 lambda 调用，然后 `k` 回到 `HALT`。
- `(+ 2 (f 20))`：普通非尾调用，看到 frame 的 `link`、`fp` 变化和 continuation 链的增长/弹出。

## 颜色

- 绿色：当前执行的指令 / 当前 `fp` / `k` 链头
- 紫色：label / continuation 节点
- 蓝色：下一条 `pc` / closure / value vector
- 灰色：不可达 frame（垃圾）

## URL 参数

可以直接跳到某一步，方便分享：

```text
index.html?scenario=callcc&step=14
index.html?scenario=direct&step=6
index.html?scenario=nontail&step=10
```

`step` 是快照编号，从 0 开始。
