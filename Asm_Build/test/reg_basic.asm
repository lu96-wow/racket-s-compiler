;; 基础 let-reg：绑定虚拟寄存器，li + 运算
(asm rv64 (rv_i)
  (label start)
  (let-reg ([x (get-reg)]
            [y (get-reg)])
    (li x 10)
    (li y 20)
    (add x x y))
  (ebreak))
