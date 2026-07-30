;; 显式绑定：x→x3, y→自动分配
;; 平级 let-reg 中 x3 应被释放后复用
(asm rv64 (rv_i)
  (label start)
  
  (let-reg ([x x3]                   ;; 显式绑定 x → x3
            [y (get-reg)])           ;; 自动分配
    (li x 1)
    (li y 2)
    (add x x y))                     ;; x=x3, y=x1(自动)
  
  ;; x3 应在此释放
  (let-reg ([z x3])                  ;; 再次显式绑定 x3，应可用
    (li z 3))
  
  (ebreak))
