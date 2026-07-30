;; 自动释放验证：两个平级 let-reg 可以复用同一个物理寄存器
(asm rv64 (rv_i)
  (label start)
  (let-reg ([x (get-reg)])          ;; x → t0
    (li x 1))
  ;; x 释放，t0 回池
  (let-reg ([y (get-reg)])          ;; y 也 → t0（复用）
    (li y 2))
  ;; 再加第三个，确认释放机制
  (let-reg ([a (get-reg)])
    (li a 3))
  (let-reg ([b (get-reg)])
    (li b 4))
  (let-reg ([c (get-reg)])
    (li c 5))
  (let-reg ([d (get-reg)])
    (li d 6))
  (let-reg ([e (get-reg)])
    (li e 7))
  ;; 7 个平级 let-reg，每个只用 1 个寄存器，不耗尽
  (ebreak))
