;; module 在 let-reg 内部：被正确提升为父模块的子模块
(asm rv64 (rv_i)
  (module math
    (provide square)
    (require (math helper) times2)    ;; require 在 let-reg 外
    (let-reg ([x (get-reg)])
      ;; module 在 let-reg 里面 → 提升为 math 的子模块
      (module helper
        (provide times2)
        (label times2)
        (add a0 a0 a0)               ;; a0 = a0 * 2
        (jalr zero ra 0))
      
      (label square)
      (li x 5)
      (jal ra times2)                ;; a0 = 5*2 = 10
      (jalr zero ra 0)))
  
  (require math square)
  (label main)
  (li a0 5)
  (jal ra square)                    ;; a0 = 10
  (ebreak))
