;; 测试：标签 + li + 跳转
(asm rv64 (rv_i)
  ;; === 基本 li 和运算 ===
  (label start)
  (li a0 42)              ;; addi a0, zero, 42
  (li a1 0)               ;; addi a1, zero, 0
  (label loop)
  (addi a1 a1 1)          ;; a1++
  (addi a0 a0 -1)         ;; a0--
  (bne loop a0 zero)      ;; 偏移在前: (bne offset rs1 rs2)
  ;; 此时 a1 应该等于 42
  (ebreak))
