;; 嵌套模块：局部函数
(asm rv64 (rv_i)
  (module kernel
    (provide syscall-handler)
    
    ;; 内部子模块 — 实现细节
    (module sys-read
      (provide do-read)
      (label do-read)
      ;; 模拟读：a0 = 42
      (li a0 42)
      (jalr zero ra 0))
    
    (module sys-write  
      (provide do-write)
      (label do-write)
      ;; 模拟写：a0 = 99
      (li a0 99)
      (jalr zero ra 0))
    
    ;; 父 require 子模块
    (require (kernel sys-read) do-read)
    (require (kernel sys-write) do-write)
    
    (label syscall-handler)
    ;; a0: syscall number (0=read, 1=write)
    (addi zero zero 0) ;; nop placeholder for dispatch
    (jal ra do-read)
    (jalr zero ra 0))
  
  (require kernel syscall-handler)
  
  (label main)
  (li a0 0)                    ;; syscall 0
  (jal ra syscall-handler)     ;; a0 = 42
  (ebreak))
