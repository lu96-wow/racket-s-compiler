;; 引用 math 模块的主程序
(asm rv64 (rv_i)
  (require math add_one sub_one)
  
  (label main)
  (li a0 10)
  (jal ra add_one)        ;; a0 = 10 + 1 = 11
  (jal ra sub_one)        ;; a0 = 11 - 1 = 10
  (ebreak))
