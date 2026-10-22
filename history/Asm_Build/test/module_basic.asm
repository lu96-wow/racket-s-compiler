;; 单模块：provides + require
(asm rv64 (rv_i)
  (module math
    (provide add_one sub_one)
    
    (label add_one)
    (addi a0 a0 1)
    (jalr zero ra 0)
    
    (label sub_one)
    (addi a0 a0 -1)
    (jalr zero ra 0))
  
  (require math add_one)
  
  (label main)
  (li a0 5)
  (jal ra add_one)        ;; a0 = 5 + 1 = 6
  (ebreak))
