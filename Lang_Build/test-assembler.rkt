#lang racket

(require racket/match
         "riscv-help.rkt")

(provide assemble
         Instr Label Jump Branch)

;; IR

(struct Instr (form) #:transparent)
(struct Label (name) #:transparent)
(struct Jump (label id) #:transparent)
(struct Branch (op label rs1 rs2 id) #:transparent)

;; ID

(define jump-counter 0)
(define branch-counter 0)

(define (make-jump label)
  (set! jump-counter (+ jump-counter 1))
  (Jump label jump-counter))

(define (make-branch op label rs1 rs2)
  (set! branch-counter (+ branch-counter 1))
  (Branch op label rs1 rs2 branch-counter))

;; lowering

(define (lower ir)
  (map
   (lambda (node)
     (match node

       [(list 'instr form)
        (Instr form)]

       [(list 'label name)
        (Label name)]

       [(list 'jump name)
        (make-jump name)]

       ;; branch DSL
       [(list 'branch form)
        (match form
          [(list op label rs1 rs2)
           (make-branch op label rs1 rs2)]
          [else
           (error "Bad branch form" form)])]

       [else
        (error "Unknown IR node" node)]))
   ir))

;; label 计算

(define (compute-labels ir jump-size-table)
  (define pc 0)
  (define table (make-hash))

  (for ([node ir])
    (match node

      [(Label name)
       (hash-set! table name pc)]

      [(Instr _)
       (set! pc (+ pc 4))]

      [(Jump _ id)
       (define sz (hash-ref jump-size-table id 1))
       (set! pc (+ pc (* 4 sz)))]

      [(Branch _ _ _ _ _)
       (set! pc (+ pc 4))]))

  table)

;; jump size

(define (calc-jump-size jump label-table pc)
  (define target (hash-ref label-table (Jump-label jump)))
  (define offset (- target pc))
  (length (generate-32-jump 'x0 offset)))

;; branch 检查

(define (branch-offset-fit? offset)
  (and (>= offset -4096) (<= offset 4094)))

;; relax
(define (relax ir)
  (define jump-size-table (make-hash))

  ;; init
  (for ([node ir])
    (when (Jump? node)
      (hash-set! jump-size-table (Jump-id node) 1)))

  (let loop ()
    (define changed #f)

    (define label-table (compute-labels ir jump-size-table))
    (define pc 0)

    (for ([node ir])
      (match node

        [(Label _) (void)]

        [(Instr _)
         (set! pc (+ pc 4))]

        [(Jump _ id)
         (define new-size (calc-jump-size node label-table pc))
         (define old-size (hash-ref jump-size-table id))

         (when (not (= new-size old-size))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))

         (set! pc (+ pc (* 4 new-size)))]

        [(Branch op label rs1 rs2 _)
         (define target (hash-ref label-table label))
         (define offset (- target pc))

         (unless (branch-offset-fit? offset)
           (error
            (format "Branch out of range: ~a -> ~a (offset ~a)"
                    op label offset)))

         (set! pc (+ pc 4))]))

    (when changed
      (loop)))

  jump-size-table)

;; emit

(define (emit ir jump-size-table)
  (define pc 0)
  (define result '())

  (define label-table (compute-labels ir jump-size-table))

  (for ([node ir])
    (match node

      ;; 普通指令
      [(Instr form)
       (set! result (append result (list form)))
       (set! pc (+ pc 4))]

      [(Label _) (void)]

      ;; jump
      [(Jump label id)
       (define target (hash-ref label-table label))
       (define offset (- target pc))

       (define instrs (generate-32-jump 'x0 offset))

       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      ;;  branch emit（关键）
      [(Branch op label rs1 rs2 _)
       (define target (hash-ref label-table label))
       (define offset (- target pc))

       ;; 注意顺序：imm rs1 rs2（匹配你编码器）
       (set! result
             (append result
                     (list `(,op ,offset ,rs1 ,rs2))))

       (set! pc (+ pc 4))]))

  result)

;; 入口

(define (assemble ir)
  (define lowered (lower ir))
  (define jump-sizes (relax lowered))
  (emit lowered jump-sizes))

