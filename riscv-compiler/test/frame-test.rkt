#lang racket/base

;; ============================================================
;; frame / env / cont / call lowering 测试
;;
;; 用一个最小 RISC-V 解释器执行最终 resolved code，
;; 验证 prologue/epilogue、env-ref/env-set、call/tailcall/return。
;; ============================================================

(require rackunit
         racket/list
         "../frame.rkt"
         "../asm.rkt"
         "../lower-frame.rkt"
         "../call-lower.rkt"
         "../compile-asm.rkt")

;; ------------------------------------------------------------
;; 最小解释器
;; ------------------------------------------------------------

(define (run-resolved code #:a0 [a0 0])
  (define regs (make-hash))
  (define mem (make-hash))
  (for ([reg (in-list
              '(x0 ra sp gp tp fp
                t0 t1 t2 t3 t4 t5 t6
                s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
                a0 a1 a2 a3 a4 a5 a6 a7))])
    (hash-set! regs reg 0))
  (hash-set! regs 'sp 4096)
  (hash-set! regs 'a0 a0)

  (define (rv reg)
    (cond
      [(eq? reg 'x0) 0]
      [(hash-has-key? regs reg) (hash-ref regs reg)]
      [else (error 'run-resolved "read undefined register: ~a" reg)]))

  (define (wr! reg value)
    (unless (eq? reg 'x0)
      (hash-set! regs reg value)))

  (define (mem-ref addr)
    (cond
      [(hash-has-key? mem addr) (hash-ref mem addr)]
      [else (error 'run-resolved "read undefined memory: ~a" addr)]))

  (define (jump-offset pc offset)
    (+ pc (quotient offset 4)))

  (let loop ([pc 0] [steps 0])
    (when (> steps 2000000)
      (error 'run-resolved "step limit"))
    (cond
      [(>= pc (length code))
       (hash-ref regs 'a0 0)]
      [else
       (define insn (list-ref code pc))
       (define m (car insn))
       (define (next) (loop (add1 pc) (add1 steps)))
       (cond
         [(eq? m 'addi)
          (wr! (cadr insn) (+ (rv (caddr insn)) (cadddr insn)))
          (next)]
         [(eq? m 'add)
          (wr! (cadr insn) (+ (rv (caddr insn)) (rv (cadddr insn))))
          (next)]
         [(eq? m 'sub)
          (wr! (cadr insn) (- (rv (caddr insn)) (rv (cadddr insn))))
          (next)]
         [(eq? m 'ld)
          ;; (ld rd offset rs1)
          (wr! (cadr insn)
               (mem-ref (+ (rv (cadddr insn)) (caddr insn))))
          (next)]
         [(eq? m 'sd)
          ;; (sd src offset rs1)
          (hash-set! mem
                     (+ (rv (cadddr insn)) (caddr insn))
                     (rv (cadr insn)))
          (next)]
         [(eq? m 'beq)
          (loop (if (= (rv (cadr insn)) (rv (caddr insn)))
                    (jump-offset pc (cadddr insn))
                    (add1 pc))
                (add1 steps))]
         [(eq? m 'bne)
          (loop (if (not (= (rv (cadr insn)) (rv (caddr insn))))
                    (jump-offset pc (cadddr insn))
                    (add1 pc))
                (add1 steps))]
         [(eq? m 'blt)
          (loop (if (< (rv (cadr insn)) (rv (caddr insn)))
                    (jump-offset pc (cadddr insn))
                    (add1 pc))
                (add1 steps))]
         [(eq? m 'bge)
          (loop (if (>= (rv (cadr insn)) (rv (caddr insn)))
                    (jump-offset pc (cadddr insn))
                    (add1 pc))
                (add1 steps))]
         [(eq? m 'jal)
          (wr! (cadr insn) (add1 pc))
          (loop (jump-offset pc (caddr insn))
                (add1 steps))]
         [(eq? m 'jalr)
          (define rd (cadr insn))
          (define rs (caddr insn))
          (define imm (cadddr insn))
          (define target (+ (rv rs) imm))
          (wr! rd (add1 pc))
          (cond
            [(zero? target) (hash-ref regs 'a0 0)]
            [else (loop target (add1 steps))])]
         [else
          (error 'run-resolved "unsupported instruction: ~a" insn)])])))

;; ------------------------------------------------------------
;; 编译 + 执行
;; ------------------------------------------------------------

(define (compile-and-run asm #:a0 [a0 0])
  (define-values (_name _program _asm _cfg _live _interference
                  regmap _coloring _labels resolved)
    (compile-asm (cons 'asm asm)))
  (values (run-resolved resolved #:a0 a0)
          regmap
          resolved))

;; ------------------------------------------------------------
;; frame 布局
;; ------------------------------------------------------------

(define sample-frame
  '(frame
    (base fp)
    (link fp)
    (slots
      (slot0 (kind arg))
      (slot1 (kind local))
      (slot2 (kind spill))
      (slot3 (kind captured)))))

(check-equal? (frame-slot-count sample-frame) 4)
(check-equal? (frame-slot-offset sample-frame 0) 16)
(check-equal? (frame-slot-offset sample-frame 3) 40)
(check-equal? (frame-saved-offset sample-frame 0) 48)
(check-equal? (frame-size sample-frame) 144)   ; 16 + 32 + 96 = 144
(check-equal? (frame-size '(frame (base fp) (link fp) (slots))) 112)

;; ------------------------------------------------------------
;; env-ref / env-set lowering
;; ------------------------------------------------------------

(let ()
  (define asm
    '((label main)
      (frame (base fp) (link fp)
             (slots (slot0 (kind arg)) (slot1 (kind local))))
      (env-set (heap 0 1) v0)
      (env-ref v1 (heap 0 1))
      (return (v1))))
  (define-values (lowered frame conts structs) (lower-frame-forms asm))
  (check-equal? frame
                '(frame (base fp) (link fp)
                        (slots (slot0 (kind arg)) (slot1 (kind local)))))
  (check-equal? conts '())
  (check-not-false (member '(sd v0 24 fp) lowered))
  (check-not-false (member '(ld v1 24 fp) lowered))
  (check-equal? (car lowered) '(label main))
  (check-equal? (cadr lowered) '(addi sp sp -128)))

;; ------------------------------------------------------------
;; call + return
;; ------------------------------------------------------------

(let ()
  (define-values (value regmap resolved)
    (compile-and-run
     '((frame (base fp) (link fp)
              (slots (slot0 (kind arg)) (slot1 (kind local))))
       (label main)
       (addi v0 x0 41)
       (env-set (heap 0 1) v0)
       (env-ref v1 (heap 0 1))
       (cont K0 (code Lafter) (env fp))
       (call f (args v1) (cont K0))
       (label Lafter)
       (return (a0))
       (label f)
       (addi a0 a0 1)
       (jalr x0 ra 0))))
  (check-equal? value 42)
  (check-true (for/or ([insn (in-list resolved)])
                (and (eq? (car insn) 'jal)
                     (eq? (cadr insn) 'ra)))))

;; ------------------------------------------------------------
;; tailcall
;; ------------------------------------------------------------

(let ()
  (define-values (value _regmap _resolved)
    (compile-and-run
     '((frame (base fp) (link fp)
              (slots (slot0 (kind arg)) (slot1 (kind local))))
       (label main)
       (addi v0 x0 41)
       (env-set (heap 0 1) v0)
       (env-ref v1 (heap 0 1))
       (tailcall f (args v1))
       (label f)
       (addi a0 a0 1)
       (jalr x0 ra 0))))
  (check-equal? value 42))

;; ------------------------------------------------------------
;; 递归调用：每次调用都分配/释放自己的 frame
;; ------------------------------------------------------------

(let ()
  (define-values (value _regmap resolved)
    (compile-and-run
     '((frame (base fp) (link fp)
              (slots (slot0 (kind arg)) (slot1 (kind local))))
       (label main)
       (env-set (heap 0 1) a0)          ; n
       (env-ref v1 (heap 0 1))
       (beq v1 x0 done)
       (addi v2 v1 -1)
       (cont K0 (code Lafter) (env fp))
       (call main (args v2) (cont K0))
       (label Lafter)
       (return (a0))
       (label done)
       (addi a0 x0 100)
       (return (a0)))
     #:a0 3))
  (check-equal? value 100)
  (check-true (for/or ([insn (in-list resolved)])
                (and (eq? (car insn) 'jal)
                     (eq? (cadr insn) 'ra)))))

;; ------------------------------------------------------------
;; 自尾递归：epilogue 先恢复 sp/fp/ra，再跳回入口，栈不增长
;; ------------------------------------------------------------

(let ()
  (define-values (value _regmap _resolved)
    (compile-and-run
     '((frame (base fp) (link fp)
              (slots (slot0 (kind arg)) (slot1 (kind local))))
       (label main)
       (env-set (heap 0 1) a0)
       (env-ref v1 (heap 0 1))
       (beq v1 x0 done)
       (addi v2 v1 -1)
       (tailcall main (args v2))
       (label done)
       (addi a0 x0 100)
       (return (a0)))
     #:a0 50))
  (check-equal? value 100))

;; ------------------------------------------------------------
;; #t/#f/'nil：固定编码 + env slot repr
;; ------------------------------------------------------------

(let ()
  (define-values (value _regmap _resolved)
    (compile-and-run
     '((frame (base fp) (link fp)
              (slots (slot0 (kind local) (repr bool))
                     (slot1 (kind local) (repr nil))))
       (label main)
       (const v0 #f)
       (const v1 'nil)
       (env-set (heap 0 0) v0)
       (env-set (heap 0 1) v1)
       (env-ref v2 (heap 0 0))
       (env-ref v3 (heap 0 1))
       (add v4 v2 v3)                 ; 7 + 23 = 30
       (return (v4)))))
  (check-equal? value 30))

;; ------------------------------------------------------------
;; 跨调用存活的值必须落到 callee-saved
;; ------------------------------------------------------------

(let ()
  (define-values (value regmap _resolved)
    (compile-and-run
     '((frame (base fp) (link fp) (slots))
       (label main)
       (addi v0 x0 7)
       (cont K0 (code Lafter) (env fp))
       (call f (args x0) (cont K0))
       (label Lafter)
       (addi a0 v0 0)
       (return (a0))
       (label f)
       (jalr x0 ra 0))))
  (check-equal? value 7)
  (define color (cdr (assoc 'v0 regmap)))
  (check-not-false (memq color '(s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11))))

;; ------------------------------------------------------------
;; 并行移动：环形交换
;; ------------------------------------------------------------

(check-equal? (parallel-move '((a0 . a1) (a1 . a0)))
              '((addi tp a1 0) (addi a1 a0 0) (addi a0 tp 0)))

(check-equal? (parallel-move '((a0 . a0) (a1 . a0)))
              '((addi a1 a0 0)))

;; 间接 tailcall 的目标在 s0 里：epilogue 会覆盖 s0，必须先搬到 gp。
(let ()
  (define lowered
    (lower-calls '((tailcall s0 (args x0)))
                 '(frame (base fp) (link fp) (slots))
                 '()))
  (check-equal? (car lowered) '(addi gp s0 0))
  (check-equal? (last lowered) '(jalr x0 gp 0)))

;; 间接 call 的目标会被参数移动覆盖：先搬到 gp。
(let ()
  (define lowered
    (lower-calls '((call a1 (args a1 a0) (cont K0)))
                 '(frame (base fp) (link fp) (slots))
                 '((K0 . Lafter))))
  (check-equal? (car lowered) '(addi gp a1 0))
  (check-not-false (member '(jalr ra gp 0) lowered)))

;; ------------------------------------------------------------
;; 错误路径
;; ------------------------------------------------------------

(check-exn
 exn:fail?
 (lambda ()
   (lower-frame-forms
    '((label main)
      (frame (base fp) (link fp) (slots))
      (env-ref v0 (heap 1 0))
      (return (v0))))))

(check-exn
 exn:fail?
 (lambda ()
   (compile-asm
    '(asm
      (frame (base fp) (link fp) (slots))
      (label main)
      (cont K0 (code Lafter) (env fp))
      (call f (args x0) (cont Missing))
      (label Lafter)
      (return (a0))
      (label f)
      (jalr x0 ra 0)))))

;; ------------------------------------------------------------
;; 原有纯 asm 路径不受影响
;; ------------------------------------------------------------

(check-false
 (extended-asm?
  '((label main)
    (addi v0 x0 1)
    (jalr x0 ra 0))))
