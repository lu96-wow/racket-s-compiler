#lang racket/base

;; ============================================================
;; liveness
;;
;; 输入：CFG
;; 输出：
;;   (liveness
;;     (B0 (use ...) (def ...) (in ...) (out ...))
;;     ...)
;;
;; 算法：
;;   out[B] = union(in[S] for S in succ(B))
;;   in[B]  = use[B] union (out[B] - def[B])
;; ============================================================

(require racket/list
         "asm.rkt"
         "frame.rkt"
         "sets.rkt"
         "cfg.rkt")

(provide compute-liveness
         instruction-use-def
         block-use-def
         liveness?
         liveness-entry
         liveness-use
         liveness-def
         liveness-in
         liveness-out)

;; ------------------------------------------------------------
;; 单条指令的 use/def
;; ------------------------------------------------------------

(define i-type-mnemonics
  '(addi addiw slti sltiu xori ori andi))

(define r-type-mnemonics
  '(add sub sll slt sltu xor srl sra or and
    addw subw sllw srlw sraw))

(define shift-imm-mnemonics
  '(slli srli srai slliw srliw sraiw))

(define u-type-mnemonics
  '(lui auipc))

(define (reg-value value)
  (and (symbol? value)
       (not (eq? value 'x0))
       value))

(define (reg-set . values)
  (sort-set (filter (lambda (value) value)
                    (map reg-value values))))

(define caller-saved-registers
  '(t0 t1 t2 t3 t4 t5 t6
    a0 a1 a2 a3 a4 a5 a6 a7
    ra))

(define (instruction-use-def instruction)
  (define mnemonic (car instruction))
  (cond
    ;; ----------------------------------------------------------
    ;; frame / env 形式（正常情况下在 CFG 之前已经 lower）
    ;; ----------------------------------------------------------
    [(call-form? instruction)
     (define args (call-args instruction))
     (define target (call-target instruction))
     (values (apply reg-set
                    (append args
                            (if (or (vreg? target)
                                    (physical-register? target))
                                (list target)
                                '())))
             (apply reg-set (quote (t0 t1 t2 t3 t4 t5 t6
                                    a0 a1 a2 a3 a4 a5 a6 a7
                                    ra))))]

    [(tailcall-form? instruction)
     (define args (tailcall-args instruction))
     (define target (tailcall-target instruction))
     (values (apply reg-set
                    (append args
                            (if (or (vreg? target)
                                    (physical-register? target))
                                (list target)
                                '())))
             (apply reg-set (quote (t0 t1 t2 t3 t4 t5 t6
                                    a0 a1 a2 a3 a4 a5 a6 a7
                                    ra))))]

    [(return-form? instruction)
     (values (apply reg-set (cadr instruction))
             '())]

    [(env-ref? instruction)
     (values (reg-set 'fp)
             (reg-set (env-ref-dst instruction)))]

    [(env-set? instruction)
     (values (reg-set 'fp (env-set-src instruction))
             '())]

    [(or (frame-form? instruction) (cont-form? instruction))
     (error 'instruction-use-def
            "declaration reached liveness: ~a"
            instruction)]

    ;; ----------------------------------------------------------
    ;; 普通指令
    ;; ----------------------------------------------------------
    [(memq mnemonic i-type-mnemonics)
     ;; rd, rs1, imm
     (values (reg-set (caddr instruction))
             (reg-set (cadr instruction)))]

    [(memq mnemonic r-type-mnemonics)
     ;; rd, rs1, rs2
     (values (reg-set (caddr instruction)
                      (cadddr instruction))
             (reg-set (cadr instruction)))]

    [(memq mnemonic shift-imm-mnemonics)
     ;; rd, rs1, shamt
     (values (reg-set (caddr instruction))
             (reg-set (cadr instruction)))]

    [(eq? mnemonic 'ld)
     ;; rd, offset, rs1
     (values (reg-set (cadddr instruction))
             (reg-set (cadr instruction)))]

    [(eq? mnemonic 'sd)
     ;; src, offset, rs1
     (values (reg-set (cadr instruction)
                      (cadddr instruction))
             '())]

    [(memq mnemonic u-type-mnemonics)
     ;; rd, imm
     (values '()
             (reg-set (cadr instruction)))]

    [(branch-instruction? instruction)
     ;; rs1, rs2, target
     (values (reg-set (cadr instruction)
                      (caddr instruction))
             '())]

    [(jal-instruction? instruction)
     ;; rd, target
     (values '()
             (reg-set (cadr instruction)))]

    [(jalr-instruction? instruction)
     ;; rd, rs1, imm
     (values (reg-set (caddr instruction))
             (reg-set (cadr instruction)))]

    [else
     (error 'instruction-use-def
            "unsupported instruction: ~a"
            instruction)]))

;; ------------------------------------------------------------
;; block 级 use/def
;; ------------------------------------------------------------

(define (block-use-def insns)
  (for/fold ([use '()]
             [def '()])
            ([instruction (in-list (reverse insns))])
    (define-values (instruction-use instruction-def)
      (instruction-use-def instruction))
    (values (set-union instruction-use
                       (set-subtract use instruction-def))
            (set-union instruction-def def))))

;; ------------------------------------------------------------
;; liveness 数据访问
;; ------------------------------------------------------------

(define (liveness? value)
  (and (list? value)
       (pair? value)
       (eq? (car value) 'liveness)))

(define (liveness-entry liveness id)
  (cond
    [(assoc id (cdr liveness)) => values]
    [else (error 'liveness-entry "unknown block: ~a" id)]))

(define (liveness-field liveness id field)
  (define entry (liveness-entry liveness id))
  (define item (assoc field (cdr entry)))
  (unless item
    (error 'liveness-field "missing field ~a for block ~a" field id))
  (cadr item))

(define (liveness-use liveness id)
  (liveness-field liveness id 'use))

(define (liveness-def liveness id)
  (liveness-field liveness id 'def))

(define (liveness-in liveness id)
  (liveness-field liveness id 'in))

(define (liveness-out liveness id)
  (liveness-field liveness id 'out))

;; ------------------------------------------------------------
;; 不动点
;; ------------------------------------------------------------

(define (compute-liveness cfg)
  (define blocks (cfg-blocks cfg))
  (define uses (make-hash))
  (define defs (make-hash))

  (for ([block (in-list blocks)])
    (define-values (use def)
      (block-use-def (block-insns block)))
    (hash-set! uses (block-id block) use)
    (hash-set! defs (block-id block) def))

  (define in (make-hash))
  (define out (make-hash))

  (let loop ()
    (define changed? #f)
    (for ([block (in-list blocks)])
      (define id (block-id block))
      (define succ (cfg-succ-of cfg id))
      (define new-out
        (sort-set
         (append-map (lambda (succ-id)
                       (hash-ref in succ-id '()))
                     succ)))
      (define new-in
        (set-union (hash-ref uses id '())
                   (set-subtract new-out
                                 (hash-ref defs id '()))))
      (unless (equal? new-out (hash-ref out id '()))
        (set! changed? #t)
        (hash-set! out id new-out))
      (unless (equal? new-in (hash-ref in id '()))
        (set! changed? #t)
        (hash-set! in id new-in)))
    (when changed?
      (loop)))

  (cons 'liveness
        (for/list ([block (in-list blocks)])
          (define id (block-id block))
          (list id
                (list 'use (hash-ref uses id '()))
                (list 'def (hash-ref defs id '()))
                (list 'in (hash-ref in id '()))
                (list 'out (hash-ref out id '()))))))
