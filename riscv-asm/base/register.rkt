#lang racket/base

;; ============================================================
;; 统一寄存器表示
;;
;; 这里只维护两张独立的表：
;;   x-registers   : x0..x31
;;   abi-registers : ABI 别名 -> x 寄存器
;;
;; 对外的规范身份是 x 寄存器（x0..x31）；查询函数同时接受：
;;   - 整数 0..31
;;   - 'x0 .. 'x31
;;   - 'zero / 'ra / 'a0 / 'fp 等 ABI 别名
;;
;; 不在这里生成指令，也不关心 RV32/RV64。
;; ============================================================

(require racket/list)

;; ------------------------------------------------------------
;; 两张源表
;; ------------------------------------------------------------

(define x-registers
  (list 'x0  'x1  'x2  'x3  'x4  'x5  'x6  'x7
        'x8  'x9  'x10 'x11 'x12 'x13 'x14 'x15
        'x16 'x17 'x18 'x19 'x20 'x21 'x22 'x23
        'x24 'x25 'x26 'x27 'x28 'x29 'x30 'x31))

;; 每个 ABI 名只对应一个 x 寄存器。
;; x8 同时有 s0 和 fp 两个标准别名，因此这里出现两行。
(define abi-registers
  (list
   (cons 'zero 'x0)
   (cons 'ra   'x1)
   (cons 'sp   'x2)
   (cons 'gp   'x3)
   (cons 'tp   'x4)
   (cons 't0   'x5)
   (cons 't1   'x6)
   (cons 't2   'x7)
   (cons 's0   'x8)
   (cons 'fp   'x8)
   (cons 's1   'x9)
   (cons 'a0   'x10)
   (cons 'a1   'x11)
   (cons 'a2   'x12)
   (cons 'a3   'x13)
   (cons 'a4   'x14)
   (cons 'a5   'x15)
   (cons 'a6   'x16)
   (cons 'a7   'x17)
   (cons 's2   'x18)
   (cons 's3   'x19)
   (cons 's4   'x20)
   (cons 's5   'x21)
   (cons 's6   'x22)
   (cons 's7   'x23)
   (cons 's8   'x24)
   (cons 's9   'x25)
   (cons 's10  'x26)
   (cons 's11  'x27)
   (cons 't3   'x28)
   (cons 't4   'x29)
   (cons 't5   'x30)
   (cons 't6   'x31)))

;; ------------------------------------------------------------
;; 派生索引
;; ------------------------------------------------------------

(define number->x-name
  (list->vector x-registers))

(define x-name->number
  (make-immutable-hash
   (for/list ([x-name (in-list x-registers)]
              [number (in-naturals)])
     (cons x-name number))))

(define abi-name->x-name
  (make-immutable-hash abi-registers))

(define x-name->abi-names
  (make-immutable-hash
   (for/list ([x-name (in-list x-registers)])
     (cons x-name
           (for/list ([entry (in-list abi-registers)]
                      #:when (eq? (cdr entry) x-name))
             (car entry))))))

;; ------------------------------------------------------------
;; 分类判断
;; ------------------------------------------------------------

(define (x-register? value)
  (and (symbol? value)
       (hash-has-key? x-name->number value)))

(define (abi-register? value)
  (and (symbol? value)
       (hash-has-key? abi-name->x-name value)))

(define (register? value)
  (and (register->number value) #t))

;; ------------------------------------------------------------
;; 规范化
;; ------------------------------------------------------------

;; 返回 0..31，非法输入返回 #f。
(define (register->number value)
  (define x-name
    (cond
      [(x-register? value) value]
      [(abi-register? value) (hash-ref abi-name->x-name value)]
      [(exact-integer? value)
       (and (<= 0 value 31)
            (vector-ref number->x-name value))]
      [else #f]))
  (and x-name (hash-ref x-name->number x-name)))

;; 返回规范 x 名（'x0 .. 'x31），非法输入返回 #f。
(define (register-x-name value)
  (cond
    [(x-register? value) value]
    [(abi-register? value) (hash-ref abi-name->x-name value)]
    [(exact-integer? value)
     (and (<= 0 value 31)
          (vector-ref number->x-name value))]
    [else #f]))

;; 返回该寄存器的首选 ABI 名。
;; x8 的首选名是 s0，fp 作为别名保留。
(define (register-abi-name value)
  (define names (register-abi-names value))
  (and (pair? names) (car names)))

;; 返回该寄存器的全部 ABI 别名，按 abi-registers 中的顺序。
(define (register-abi-names value)
  (define x-name (register-x-name value))
  (if x-name
      (hash-ref x-name->abi-names x-name '())
      '()))

;; ------------------------------------------------------------
;; 比较与分类
;; ------------------------------------------------------------

(define (same-register? a b)
  (define na (register->number a))
  (define nb (register->number b))
  (cond
    [(and na nb) (= na nb)]
    ;; 保留旧行为：未知符号/虚拟寄存器按 eq? 比较。
    [else (eq? a b)]))

(define (zero-register? value)
  (define number (register->number value))
  (and number (zero? number)))

(define (nonzero-register? value)
  (define number (register->number value))
  (and number (not (zero? number))))

;; RISC-V 压缩字段 rd' / rs1' / rs2' 只能编码 x8..x15。
(define (compressed-prime-register? value)
  (define number (register->number value))
  (and number (<= 8 number 15)))

;; C.BEQZ / C.BNEZ 使用 rs1'。
(define (compressed-branch-register? value)
  (compressed-prime-register? value))

(provide x-registers
         abi-registers
         x-register?
         abi-register?
         register?
         register->number
         register-x-name
         register-abi-name
         register-abi-names
         same-register?
         zero-register?
         nonzero-register?
         compressed-prime-register?
         compressed-branch-register?)
