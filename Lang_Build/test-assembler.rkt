#lang racket

(require racket/match
         "riscv-help.rkt")

(provide assemble
         Instr Label Jump32 Jump64 Branch LoadImm32 LoadImm64)

;; IR

(struct Instr (form) #:transparent)
(struct Label (name) #:transparent)

(struct Jump32 (label rd id) #:transparent)
(struct Jump64 (label rd tmp id) #:transparent)

(struct LoadImm32 (rd imm) #:transparent)
(struct LoadImm64 (rd imm tmp) #:transparent)

(struct Branch (op label rs1 rs2) #:transparent)

;; ID

(define jump-counter 0)

(define (make-jump32 label [rd 'x0])
  (set! jump-counter (+ jump-counter 1))
  (Jump32 label rd jump-counter))

(define (make-jump64 label rd tmp)
  (set! jump-counter (+ jump-counter 1))
  (Jump64 label rd tmp jump-counter))

;; lowering

(define (lower ir)
  (map
   (lambda (node)
     (match node

       [(list 'instr form)
        (Instr form)]

       [(list 'label name)
        (Label name)]

       ;; jump32
       [(list 'jump32 name)
        (make-jump32 name)]

       [(list 'jump32 name rd)
        (make-jump32 name rd)]

       ;; jump64
       [(list 'jump64 name rd tmp)
        (make-jump64 name rd tmp)]

       ;; load immediate
       [(list 'load-immediate32 rd imm)
        (LoadImm32 rd imm)]

       [(list 'load-immediate64 rd imm tmp)
        (LoadImm64 rd imm tmp)]

       ;; branch
       [(list 'branch form)
        (match form
          [(list op label rs1 rs2)
           (Branch op label rs1 rs2)]
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

      [(Jump32 _ _ id)
       (define sz (hash-ref jump-size-table id 1))
       (set! pc (+ pc (* 4 sz)))]

      [(Jump64 _ _ _ id)
       (define sz (hash-ref jump-size-table id 1))
       (set! pc (+ pc (* 4 sz)))]

      [(LoadImm32 _ _)
       ;; variable length
       (set! pc (+ pc (* 4 2)))]

      [(LoadImm64 _ _ _)
       (set! pc (+ pc (* 4 4)))]

      [(Branch _ _ _ _)
       (set! pc (+ pc 4))]))

  table)

;; jump size

(define (calc-jump32-size jump label-table pc)
  (define target (hash-ref label-table (Jump32-label jump)))
  (define offset (- target pc))
  (length (generate-32-jump (Jump32-rd jump) offset)))

(define (calc-jump64-size jump label-table pc)
  (define target (hash-ref label-table (Jump64-label jump)))
  (define offset (- target pc))
  (length (generate-64-jump (Jump64-rd jump)
                            offset
                            (Jump64-tmp jump))))

;; relax

(define (relax ir)
  (define jump-size-table (make-hash))

  ;; init
  (for ([node ir])
    (cond
      [(Jump32? node)
       (hash-set! jump-size-table (Jump32-id node) 1)]
      [(Jump64? node)
       (hash-set! jump-size-table (Jump64-id node) 1)]))

  (let loop ()
    (define changed #f)

    (define label-table (compute-labels ir jump-size-table))
    (define pc 0)

    (for ([node ir])
      (match node

        [(Label _) (void)]

        [(Instr _)
         (set! pc (+ pc 4))]

        [(Jump32 _ _ id)
         (define new-size (calc-jump32-size node label-table pc))
         (define old-size (hash-ref jump-size-table id))
         (when (not (= new-size old-size))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        [(Jump64 _ _ _ id)
         (define new-size (calc-jump64-size node label-table pc))
         (define old-size (hash-ref jump-size-table id))
         (when (not (= new-size old-size))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        [(LoadImm32 _ _)
         (set! pc (+ pc (* 4 2)))]

        [(LoadImm64 _ _ _)
         (set! pc (+ pc (* 4 4)))]

        [(Branch op label rs1 rs2)
         (define target (hash-ref label-table label))
         (define offset (- target pc))
         (unless (and (>= offset -4096) (<= offset 4094))
           (error "Branch out of range"))
         (set! pc (+ pc 4))]))

    (when changed (loop)))

  jump-size-table)

;; emit

(define (emit ir jump-size-table)
  (define pc 0)
  (define result '())

  (define label-table (compute-labels ir jump-size-table))

  (for ([node ir])
    (match node

      [(Instr form)
       (set! result (append result (list form)))
       (set! pc (+ pc 4))]

      [(Label _) (void)]

      [(Jump32 label rd id)
       (define target (hash-ref label-table label))
       (define offset (- target pc))
       (define instrs (generate-32-jump rd offset))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump64 label rd tmp id)
       (define target (hash-ref label-table label))
       (define offset (- target pc))
       (define instrs (generate-64-jump rd offset tmp))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadImm32 rd imm)
       (define instrs (load-immediate-number-32 rd imm))
       (unless instrs (error "Invalid imm32"))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadImm64 rd imm tmp)
       (define instrs (load-immediate-number-64 rd imm tmp))
       (unless instrs (error "Invalid imm64"))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Branch op label rs1 rs2)
       (define target (hash-ref label-table label))
       (define offset (- target pc))
       (set! result (append result (list `(,op ,offset ,rs1 ,rs2))))
       (set! pc (+ pc 4))]))

  result)

;; 入口

(define (assemble ir)
  (define lowered (lower ir))
  (define jump-sizes (relax lowered))
  (emit lowered jump-sizes))