;; 综合测试：各种 li + 跳转模式
(asm rv64 (rv_i rv64_i)
  ;; === li 覆盖所有路径 ===
  (label start)
  (li t0 42)                     ;; Case 1: 12bit 有符号 → 单条 addi
  (li t1 -2048)                  ;; Case 1: 12bit 最小
  (li t2 2047)                   ;; Case 1: 12bit 最大
  (li t3 #x12345000)            ;; Case 2: 32bit sign-ext, lo=0 → 单条 lui
  (li t4 #x12345678)            ;; Case 2: 32bit sign-ext, lo≠0 → lui+addi
  (li t5 #x1234500000000000)    ;; Case 3: 低32位=0 → lui+slli
  (li t6 #xFFFFFFFFFFFFF000)    ;; Case 2: 负数 sign-ext → 单条 lui
  (li a0 -1)                     ;; Case 1: 12bit 负数 → addi rd, x0, -1
  (li a1 4096)                   ;; 超过12bit → lui+addi

  ;; === 跳转测试 ===
  (li a2 0)
  (label loop)
  (addi a2 a2 1)
  (li a3 5)
  (bne loop a2 a3)              ;; 偏移在前，向后跳转
  (label end)
  (ebreak))
