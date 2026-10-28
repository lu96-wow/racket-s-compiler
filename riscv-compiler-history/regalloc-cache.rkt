#lang racket/base

;; ============================================================
;; 缓存式寄存器分配（函数式模型的实验实现）
;;
;; 模型：
;;   - 每个 vreg 是一个不可变值，永久住在自己的 frame slot 里。
;;   - 物理寄存器只是这个 frame 的缓存。
;;   - 用 use 之前 load，定义之后标脏，驱逐/块尾时 store。
;;   - 块边界 = 缓存清空（vreg 回落到 frame）。
;;
;; 这不是要替代图着色，而是证明：
;;   溢出 = 缓存驱逐，不需要 spill 循环，也不需要 caller/callee-saved。
;;
;; 输入：纯 vreg asm + CFG + liveness
;; 输出：物理寄存器 asm + load-slot/store-slot + slot-map
;; ============================================================

(require racket/list
         "asm.rkt"
         "cfg.rkt"
         "liveness.rkt"
         "regalloc-graph.rkt")

(provide cache-allocate-registers
         cache-slot-of)

;; ------------------------------------------------------------
;; 名字 / 槽
;; ------------------------------------------------------------

(define (cache-slot-of vreg)
  (string->symbol (format "slot~a" (vreg-index vreg))))

(define (all-register-symbols)
  '(x0 ra sp gp tp
    t0 t1 t2 t3 t4 t5 t6
    s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
    a0 a1 a2 a3 a4 a5 a6 a7))

(define (collect-precolored asm)
  (sort
   (remove-duplicates
    (for*/list ([item (in-list asm)]
                #:when (instruction? item)
                [operand (in-list (cdr item))]
                #:when (and (symbol? operand)
                            (memq operand (all-register-symbols))
                            (not (vreg? operand))))
      operand))
   symbol<?))

(define (collect-vregs cfg)
  (sort
   (remove-duplicates
    (for*/list ([block (in-list (cfg-blocks cfg))]
                [insn (in-list (block-insns block))]
                [operand (in-list (cdr insn))]
                #:when (vreg? operand))
      operand))
   < #:key vreg-index))

(define (instruction-vreg-uses insn)
  (define-values (use _def) (instruction-use-def insn))
  (filter vreg? use))

;; ------------------------------------------------------------
;; 指令替换：只替换 resident 里的 vreg
;; ------------------------------------------------------------

(define (subst-instruction insn resident)
  (cons (car insn)
        (for/list ([operand (in-list (cdr insn))])
          (cond
            [(and (symbol? operand) (hash-has-key? resident operand))
             (hash-ref resident operand)]
            [else operand]))))

;; ------------------------------------------------------------
;; 主过程
;; ------------------------------------------------------------

(define (cache-allocate-registers asm cfg liveness
                                  #:pool [requested-pool physical-pool])
  (define precolored (collect-precolored asm))
  (define pool
    (remove* precolored requested-pool))
  (unless (pair? pool)
    (error 'cache-allocate-registers
           "empty register pool after removing precolored ~a"
           precolored))

  (define vregs (collect-vregs cfg))
  (define slot-map
    (for/list ([v (in-list vregs)])
      (cons v (cache-slot-of v))))

  (define emitted '())
  (define (emit! insn) (set! emitted (cons insn emitted)))

  ;; 每个 block 重置的缓存状态。
  (define resident (make-hash))      ; vreg -> preg
  (define owner (make-hash))         ; preg -> vreg
  (define dirty (make-hash))         ; vreg -> #t
  (define free '())                  ; 空闲 preg

  (define (next-use uses-vec i v)
    (let loop ([j (add1 i)])
      (cond
        [(>= j (vector-length uses-vec)) (vector-length uses-vec)]
        [(memq v (vector-ref uses-vec j)) j]
        [else (loop (add1 j))])))

  (define (evict! uses-vec i pinned)
    (define candidates
      (for/list ([v (in-list (sort (hash-keys resident) symbol<?))]
                 #:when (not (memq v pinned)))
        v))
    (unless (pair? candidates)
      (error 'cache-allocate-registers
             "register pressure too high at instruction ~a: need more than ~a registers"
             i (length pool)))
    ;; 最远下次使用优先（Belady）。
    (define victim
      (car (sort candidates
                 (lambda (a b)
                   (define na (next-use uses-vec i a))
                   (define nb (next-use uses-vec i b))
                   (cond
                     [(= na nb) (> (vreg-index a) (vreg-index b))]
                     [else (> na nb)])))))
    (define reg (hash-ref resident victim))
    (when (hash-has-key? dirty victim)
      (emit! (list 'store-slot (cache-slot-of victim) reg))
      (hash-remove! dirty victim))
    (hash-remove! resident victim)
    (hash-remove! owner reg)
    reg)

  (define (alloc-preg! uses-vec i pinned)
    (cond
      [(pair? free)
       (define reg (car free))
       (set! free (cdr free))
       reg]
      [else (evict! uses-vec i pinned)]))

  (define (ensure-resident! uses-vec i pinned v load?)
    (unless (hash-has-key? resident v)
      (define reg (alloc-preg! uses-vec i pinned))
      (hash-set! resident v reg)
      (hash-set! owner reg v)
      (when load?
        (emit! (list 'load-slot reg (cache-slot-of v))))))

  (for ([block (in-list (cfg-blocks cfg))])
    ;; 块边界：缓存整体失效，frame 是唯一真相。
    (set! resident (make-hash))
    (set! owner (make-hash))
    (set! dirty (make-hash))
    (set! free pool)

    (for ([label (in-list (block-labels block))])
      (emit! (list 'label label)))

    (define insns (block-insns block))
    (define uses-vec
      (for/vector ([insn (in-list insns)])
        (instruction-vreg-uses insn)))

    (define (process! insn i)
      (define-values (use def) (instruction-use-def insn))
      (define use-vregs (filter vreg? use))
      (define def-vregs (filter vreg? def))
      (define pinned (append use-vregs def-vregs))

      (for ([v (in-list use-vregs)])
        (ensure-resident! uses-vec i pinned v #t))
      (for ([v (in-list def-vregs)])
        (ensure-resident! uses-vec i pinned v #f))

      (emit! (subst-instruction insn resident))

      (for ([v (in-list def-vregs)])
        (hash-set! dirty v #t)))

    ;; 写回必须发生在 terminator 之前，否则跳转会把 store 跳过。
    (define live-out (liveness-out liveness (block-id block)))
    (define (flush!)
      (for ([v (in-list (sort (hash-keys dirty) symbol<?))])
        (when (and (memq v live-out)
                   (hash-has-key? resident v))
          (emit! (list 'store-slot
                       (cache-slot-of v)
                       (hash-ref resident v))))))

    (define terminator-index
      (and (pair? insns) (terminator? (last insns))
           (sub1 (length insns))))

    (if terminator-index
        (begin
          (for ([insn (in-list (drop-right insns 1))]
                [i (in-naturals)])
            (process! insn i))
          (flush!)
          (process! (last insns) terminator-index))
        (begin
          (for ([insn (in-list insns)]
                [i (in-naturals)])
            (process! insn i))
          (flush!))))

  (values (reverse emitted)
          slot-map
          pool
          precolored))
