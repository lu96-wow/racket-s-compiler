;; let-reg 与 module 混用：各管各的
(asm rv64 (rv_i)
  (module math
    (provide square)
    (let-reg ([x (get-reg)])
      (label square)
      (li x 5)
      (add a0 a0 x)      ;; a0 = a0 + 5
      (jalr zero ra 0)))
  
  (require math square)
  (label main)
  (li a0 10)
  (jal ra square)        ;; a0 = 15
  (ebreak))
