#lang racket/base

;; ============================================================
;; regalloc-cache 实验测试
;;
;; 验证方式：写一个最小 RISC-V 解释器，
;; 分别执行原始 vreg asm 和缓存分配后的物理寄存器 asm，
;; 要求两者结果一致；并且分配结果里确实出现了 load-slot/store-slot。
;; ============================================================

(require rackunit
         racket/list
         "../asm.rkt"
         "../cfg.rkt"
         "../liveness.rkt"
         "../regalloc-cache.rkt")

;; ------------------------------------------------------------
;; 生成测试程序
;; ------------------------------------------------------------

;; n 个独立值，全部在链式求和时仍然 live。
(define (pressure-program n)
  (define defs
    (for/list ([i (in-range n)])
      (list 'addi (string->symbol (format "v~a" i)) 'x0 (add1 i))))
  (define-values (sums last-sum _next-id)
    (for/fold ([acc '()]
               [prev 'v0]
               [next-id n])
              ([i (in-range 1 n)])
      (define v (string->symbol (format "v~a" next-id)))
      (values (cons (list 'add v prev (string->symbol (format "v~a" i)))
                    acc)
              v
              (add1 next-id))))
  (append
   (list (list 'label 'main))
   defs
   (reverse sums)
   (list (list 'addi 'a0 last-sum 0)
         (list 'jalr 'x0 'ra 0))))

;; 同一批值跨块存活：B1 定义，B3 使用。
(define (pressure-program-across-blocks n)
  (define defs
    (for/list ([i (in-range n)])
      (list 'addi (string->symbol (format "v~a" i)) 'x0 (add1 i))))
  (define-values (sums last-sum _next-id)
    (for/fold ([acc '()]
               [prev 'v0]
               [next-id n])
              ([i (in-range 1 n)])
      (define v (string->symbol (format "v~a" next-id)))
      (values (cons (list 'add v prev (string->symbol (format "v~a" i)))
                    acc)
              v
              (add1 next-id))))
  (append
   (list (list 'label 'main)
         (list 'addi 'a0 'x0 1)
         (list 'beq 'a0 'x0 'L1))
   defs
   (list (list 'bge 'a0 'a0 'L0)
         (list 'label 'L1)
         (list 'addi 'a0 'x0 -1)
         (list 'jalr 'x0 'ra 0)
         (list 'label 'L0))
   (reverse sums)
   (list (list 'addi 'a0 last-sum 0)
         (list 'jalr 'x0 'ra 0))))

;; ------------------------------------------------------------
;; 最小解释器
;; ------------------------------------------------------------

(define (asm->machine asm)
  (define labels (make-hash))
  (define insns '())
  (define pc 0)
  (for ([item (in-list asm)])
    (cond
      [(label? item)
       (hash-set! labels (cadr item) pc)]
      [(instruction? item)
       (set! insns (cons item insns))
       (set! pc (add1 pc))]
      [else (error 'asm->machine "bad item: ~a" item)]))
  (values (reverse insns) labels))

(define (run asm)
  (define-values (insns labels) (asm->machine asm))
  (define insn-vec (list->vector insns))
  (define regs (make-hash))
  (define slots (make-hash))

  (define (rv r)
    (cond
      [(eq? r 'x0) 0]
      [(hash-has-key? regs r) (hash-ref regs r)]
      [else (error 'run "read undefined register: ~a" r)]))

  (define (wr! r v)
    (unless (eq? r 'x0)
      (hash-set! regs r v)))

  (define (jump target)
    (cond
      [(hash-has-key? labels target) (hash-ref labels target)]
      [(exact-integer? target) target]
      [else (error 'run "bad target: ~a" target)]))

  (let loop ([pc 0] [steps 0])
    (when (> steps 1000000)
      (error 'run "step limit"))
    (cond
      [(>= pc (vector-length insn-vec))
       (hash-ref regs 'a0 0)]
      [else
       (define insn (vector-ref insn-vec pc))
       (define m (car insn))
       (define next (add1 pc))
       (cond
         [(eq? m 'addi)
          (wr! (cadr insn) (+ (rv (caddr insn)) (cadddr insn)))
          (loop next (add1 steps))]
         [(eq? m 'add)
          (wr! (cadr insn) (+ (rv (caddr insn)) (rv (cadddr insn))))
          (loop next (add1 steps))]
         [(eq? m 'sub)
          (wr! (cadr insn) (- (rv (caddr insn)) (rv (cadddr insn))))
          (loop next (add1 steps))]
         [(eq? m 'load-slot)
          (define slot (caddr insn))
          (unless (hash-has-key? slots slot)
            (error 'run "load of undefined slot: ~a at pc ~a" slot pc))
          (wr! (cadr insn) (hash-ref slots slot))
          (loop next (add1 steps))]
         [(eq? m 'store-slot)
          (hash-set! slots (cadr insn) (rv (caddr insn)))
          (loop next (add1 steps))]
         [(eq? m 'beq)
          (loop (if (= (rv (cadr insn)) (rv (caddr insn)))
                    (jump (cadddr insn))
                    next)
                (add1 steps))]
         [(eq? m 'bne)
          (loop (if (not (= (rv (cadr insn)) (rv (caddr insn))))
                    (jump (cadddr insn))
                    next)
                (add1 steps))]
         [(eq? m 'blt)
          (loop (if (< (rv (cadr insn)) (rv (caddr insn)))
                    (jump (cadddr insn))
                    next)
                (add1 steps))]
         [(eq? m 'bge)
          (loop (if (>= (rv (cadr insn)) (rv (caddr insn)))
                    (jump (cadddr insn))
                    next)
                (add1 steps))]
         [(eq? m 'jal)
          (loop (jump (caddr insn)) (add1 steps))]
         [(eq? m 'jalr)
          (cond
            [(and (eq? (cadr insn) 'x0)
                  (eq? (caddr insn) 'ra))
             (hash-ref regs 'a0 0)]
            [else (error 'run "unsupported jalr: ~a" insn)])]
         [else
          (error 'run "unsupported instruction: ~a" insn)])])))

;; ------------------------------------------------------------
;; 测试
;; ------------------------------------------------------------

(define (check-one name asm #:pool pool)
  (define cfg (build-cfg asm))
  (define live (compute-liveness cfg))
  (define-values (allocated slot-map used-pool precolored)
    (cache-allocate-registers asm cfg live #:pool pool))

  (define expected (run asm))
  (define actual (run allocated))

  (check-equal? actual expected (format "~a: value" name))
  (check-equal? (length used-pool) (length (remove* precolored pool))
                (format "~a: pool" name))

  ;; 分配结果只能出现物理寄存器、slot 和 label。
  (for ([item (in-list allocated)]
        #:when (instruction? item))
    (for ([operand (in-list (cdr item))])
      (check-false (vreg? operand)
                   (format "~a: vreg leaked: ~a" name operand))))

  ;; 小池子必须产生溢出。
  (define spilled?
    (for/or ([item (in-list allocated)])
      (and (instruction? item)
           (memq (car item) '(load-slot store-slot))
           #t)))
  (check-true spilled? (format "~a: expected spill" name))

  (void))

;; 26 个物理寄存器的默认池，40 个同时 live 的值。
(check-one "single-block" (pressure-program 40) #:pool
           '(t0 t1 t2 t3 t4 t5 t6 s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
             a1 a2 a3 a4 a5 a6 a7))

(check-one "across-blocks" (pressure-program-across-blocks 40) #:pool
           '(t0 t1 t2 t3 t4 t5 t6 s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
             a1 a2 a3 a4 a5 a6 a7))

;; 极小池子（4 个寄存器）也必须正确。
(check-one "tiny-pool" (pressure-program 30) #:pool '(t0 t1 t2 t3))

;; 无压力时不应该溢出。
(define small-asm
  '((label main)
    (addi v0 x0 1)
    (addi v1 x0 2)
    (add v2 v0 v1)
    (addi a0 v2 0)
    (jalr x0 ra 0)))

(let ()
  (define cfg (build-cfg small-asm))
  (define live (compute-liveness cfg))
  (define-values (allocated _slot-map _pool _pre)
    (cache-allocate-registers small-asm cfg live))
  (check-equal? (run allocated) 3)
  (check-false (for/or ([item (in-list allocated)])
                 (and (instruction? item)
                      (memq (car item) '(load-slot store-slot))
                      #t))
               "small program should not spill"))
