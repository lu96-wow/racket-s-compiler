;; 测试分支展开：向后跳转 > 4KB
(asm rv64 (rv_i)
  (label start)
  (li a0 1)
  ;; 用 .zero 或大量 nop 填充超过 4KB
  ;; 实际上：用足够多的指令撑到 >4096 字节
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  (addi zero zero 0)
  ;; 10 × 4 = 40 字节，远不够。需要 1024 条。
  ;; 所以我们用一个更实际的测试：跳转偏移刚好超出 ±4KB
  )
