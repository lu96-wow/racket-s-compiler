;; module+ 继承父模块的私有符号
(asm rv64 (rv_i)
  (module my-lib
    (provide public-api)
    
    ;; 私有辅助函数
    (label private-helper)
    (addi a0 a0 10)
    (jalr zero ra 0)
    
    ;; module+: 可以访问父模块的 private-helper
    (module+ test
      (provide run-test)
      (label run-test)
      (jal ra private-helper)     ;; OK: module+ 继承父符号
      (jalr zero ra 0))
    
    (label public-api)
    (jal ra private-helper)
    (jalr zero ra 0))
  
  ;; 从 my-lib 导入，从 my-lib/test 导入
  (require my-lib public-api)
  (require (my-lib test) run-test)
  
  (label main)
  (li a0 5)
  (jal ra public-api)         ;; a0 = 5 + 10 = 15
  (jal ra run-test)           ;; a0 = 15 + 10 = 25
  (ebreak))
