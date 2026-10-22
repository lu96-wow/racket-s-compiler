;; 嵌套 let-reg：内外层寄存器绑定
(asm rv64 (rv_i)
  (label start)
  (let-reg ([x (get-reg)])
    (li x 10)
    (let-reg ([y (get-reg)])
      (li y 20)
      (add x x y))       ;; x 来自外层
    (addi x x 1))        ;; y 已释放
  (ebreak))
