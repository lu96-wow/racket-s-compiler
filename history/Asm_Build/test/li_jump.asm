;; 测试：lui 范围 li + 前后跳转
(asm rv64 (rv_i)
  (li a0 #x12345000)      ;; lui+addi
  (li a1 0)
  (jal zero skip)
  (label here)
  (addi a1 a1 1)          ;; 不应执行
  (label skip)
  (li a2 #xFFFFFFFFFFFFF000)  ;; 负数立即数 (fits-in-32-bit)
  (label end)
  (jal zero end))
