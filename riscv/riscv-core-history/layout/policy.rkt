#lang racket
;;; layout/policy.rkt
;;;
;;; 布局策略集中在这里。pass 只执行 policy，不自己发明规则。
;;;
;;; 第一版默认：
;;;   - block 顺序：text order，entry 放最前
;;;   - 远条件分支：先 inline（islands 是下一步）
;;;   - 远无条件跳转：先 inline（islands 是下一步）
;;;   - scratch：feedback（统一预算协商）
;;;   - RVC：关闭

(provide (struct-out layout-policy)
         default-layout-policy
         make-layout-policy
         policy-valid?)

(struct layout-policy
  (order          ; 'text | 'greedy | 'profile
   far-branch     ; 'islands | 'inline | 'indirect
   far-jump       ; 'islands | 'inline | 'indirect
   scratch        ; 'feedback | 'conservative
   rvc?)          ; boolean
  #:transparent)

(define default-layout-policy
  (layout-policy 'text 'inline 'inline 'feedback #f))

(define (make-layout-policy #:order [order 'text]
                            #:far-branch [far-branch 'islands]
                            #:far-jump [far-jump 'islands]
                            #:scratch [scratch 'feedback]
                            #:rvc? [rvc? #f])
  (define p (layout-policy order far-branch far-jump scratch rvc?))
  (unless (policy-valid? p)
    (error 'layout-policy "invalid layout policy: ~e" p))
  p)

(define (policy-valid? p)
  (and (layout-policy? p)
       (memq (layout-policy-order p) '(text greedy profile))
       (memq (layout-policy-far-branch p) '(islands inline indirect))
       (memq (layout-policy-far-jump p) '(islands inline indirect))
       (memq (layout-policy-scratch p) '(feedback conservative))
       (boolean? (layout-policy-rvc? p))))
