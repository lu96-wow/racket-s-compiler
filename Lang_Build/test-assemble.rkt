#lang racket

(require racket/match
         "riscv-help.rkt")

(provide assemble
         Instruction Label
         Jump32 Jump64
         Jump32Absolute Jump64Absolute
         Branch
         LoadImm32 LoadImm64
         LoadAddress32 LoadAddress64
         Hole)

;; =========================
;; IR 定义
;; =========================

(struct Instruction (forms) #:transparent)
(struct Label (name) #:transparent)

(struct Jump32 (label rd id) #:transparent)
(struct Jump64 (label rd tmp id) #:transparent)

(struct Jump32Absolute (label rd addr-reg) #:transparent)
(struct Jump64Absolute (label rd addr-reg tmp-reg) #:transparent)

(struct LoadImm32 (rd imm) #:transparent)
(struct LoadImm64 (rd imm tmp) #:transparent)
(struct LoadAddress32 (rd label) #:transparent)
(struct LoadAddress64 (rd label tmp) #:transparent)

(struct Branch (op label rs1 rs2) #:transparent)
(struct Hole (size) #:transparent)

;; =========================
;; ID 生成
;; =========================

(define jump-counter 0)

(define (make-jump32 label [rd 'x0])
  (set! jump-counter (+ jump-counter 1))
  (Jump32 label rd jump-counter))

(define (make-jump64 label rd tmp)
  (set! jump-counter (+ jump-counter 1))
  (Jump64 label rd tmp jump-counter))

;; =========================
;; LOWER
;; =========================

(define (lower ir)
  (map
   (lambda (node)
     (match node
       [(list 'instruction forms ...)
        (Instruction forms)]

       [(list 'label name) (Label name)]
       [(list 'hole size) (Hole size)]

       ;; 相对跳转
       [(list 'jump32 name) (make-jump32 name)]
       [(list 'jump32 name rd) (make-jump32 name rd)]
       [(list 'jump64 name rd tmp) (make-jump64 name rd tmp)]

       ;; 绝对跳转
       [(list 'jump32-absolute label rd addr-reg)
        (Jump32Absolute label rd addr-reg)]

       [(list 'jump64-absolute label rd addr-reg tmp-reg)
        (Jump64Absolute label rd addr-reg tmp-reg)]

       [(list 'load-immediate32 rd imm) (LoadImm32 rd imm)]
       [(list 'load-immediate64 rd imm tmp) (LoadImm64 rd imm tmp)]

       [(list 'load-address32 rd label) (LoadAddress32 rd label)]
       [(list 'load-address64 rd label tmp) (LoadAddress64 rd label tmp)]

       [(list 'branch form)
        (match form
          [(list op label rs1 rs2)
           (Branch op label rs1 rs2)]
          [else (error "Bad branch form" form)])]

       [else (error "Unknown IR node" node)]))
   ir))

;; =========================
;; compute-labels（统一用真实长度）
;; =========================

(define (compute-labels ir jump-size-table base)
  (define pc base)
  (define table (make-hash))

  (define (safe-first-label name)
    (car (hash-ref table name '(0))))

  (for ([node ir])
    (match node
      [(Label name)
       (hash-update! table name
                     (lambda (lst) (cons pc lst))
                     '())]

      [(Hole size)
       (set! pc (+ pc size))]

      [(Instruction forms)
       (set! pc (+ pc (* 4 (length forms))))]

      [(Jump32 _ _ id)
       (set! pc (+ pc (* 4 (hash-ref jump-size-table id 1))))]

      [(Jump64 _ _ _ id)
       (set! pc (+ pc (* 4 (hash-ref jump-size-table id 1))))]

      ;; ========= 变长指令全部动态 =========

      [(LoadImm32 rd imm)
       (define instrs (load-immediate-number-32 rd imm))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadImm64 rd imm tmp)
       (define instrs (load-immediate-number-64 rd imm tmp))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadAddress32 rd label)
       (define addr (safe-first-label label))
       (define instrs (load-immediate-number-32 rd addr))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadAddress64 rd label tmp)
       (define addr (safe-first-label label))
       (define instrs (load-immediate-number-64 rd addr tmp))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump32Absolute label rd addr-reg)
       (define addr (safe-first-label label))
       (define instrs (jump-to-absolute-32 rd addr-reg addr))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump64Absolute label rd addr-reg tmp-reg)
       (define addr (safe-first-label label))
       (define instrs (jump-to-absolute-64 rd addr-reg tmp-reg addr))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Branch _ _ _ _)
       (set! pc (+ pc 4))]))

  table)

;; =========================
;; relax（扩展到所有变长指令）
;; =========================

(define (relax ir base)
  (define jump-size-table (make-hash))

  ;; 初始化 jump
  (for ([node ir])
    (cond
      [(Jump32? node)
       (hash-set! jump-size-table (Jump32-id node) 1)]
      [(Jump64? node)
       (hash-set! jump-size-table (Jump64-id node) 1)]))

  (let loop ()
    (define changed #f)
    (define label-table (compute-labels ir jump-size-table base))
    (define pc base)

    (for ([node ir])
      (match node
        [(Label _) (void)]

        [(Hole size)
         (set! pc (+ pc size))]

        [(Instruction forms)
         (set! pc (+ pc (* 4 (length forms))))]

        ;; jump（已有）
        [(Jump32 label rd id)
         (define offset (- (car (hash-ref label-table label)) pc))
         (define new-size (length (generate-32-jump rd offset)))
         (define old-size (hash-ref jump-size-table id))
         (when (not (= new-size old-size))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        [(Jump64 label rd tmp id)
         (define offset (- (car (hash-ref label-table label)) pc))
         (define new-size (length (generate-64-jump rd offset tmp)))
         (define old-size (hash-ref jump-size-table id))
         (when (not (= new-size old-size))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        ;; ========= 新增：其它全部动态 =========

        [(LoadImm32 rd imm)
         (define sz (length (load-immediate-number-32 rd imm)))
         (set! pc (+ pc (* 4 sz)))]

        [(LoadImm64 rd imm tmp)
         (define sz (length (load-immediate-number-64 rd imm tmp)))
         (set! pc (+ pc (* 4 sz)))]

        [(LoadAddress32 rd label)
         (define addr (car (hash-ref label-table label)))
         (define sz (length (load-immediate-number-32 rd addr)))
         (set! pc (+ pc (* 4 sz)))]

        [(LoadAddress64 rd label tmp)
         (define addr (car (hash-ref label-table label)))
         (define sz (length (load-immediate-number-64 rd addr tmp)))
         (set! pc (+ pc (* 4 sz)))]

        [(Jump32Absolute label rd addr-reg)
         (define addr (car (hash-ref label-table label)))
         (define sz (length (jump-to-absolute-32 rd addr-reg addr)))
         (set! pc (+ pc (* 4 sz)))]

        [(Jump64Absolute label rd addr-reg tmp-reg)
         (define addr (car (hash-ref label-table label)))
         (define sz (length (jump-to-absolute-64 rd addr-reg tmp-reg addr)))
         (set! pc (+ pc (* 4 sz)))]

        [(Branch _ _ _ _)
         (set! pc (+ pc 4))]))

    (when changed (loop)))

  jump-size-table)

;; =========================
;; emit（统一动态长度）
;; =========================

(define (emit ir jump-size-table base)
  (define pc base)
  (define result '())
  (define label-table (compute-labels ir jump-size-table base))

  (for ([node ir])
    (match node
      [(Instruction forms)
       (set! result (append result forms))
       (set! pc (+ pc (* 4 (length forms))))]

      [(Label _) (void)]

      [(Hole size)
       (define nops
         (make-list (quotient size 4) '(addi x0 x0 0)))
       (set! result (append result nops))
       (set! pc (+ pc size))]

      ;; ========= 全部统一动态 =========

      [(LoadImm32 rd imm)
       (define instrs (load-immediate-number-32 rd imm))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadImm64 rd imm tmp)
       (define instrs (load-immediate-number-64 rd imm tmp))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadAddress32 rd label)
       (define addr (car (hash-ref label-table label)))
       (define instrs (load-immediate-number-32 rd addr))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(LoadAddress64 rd label tmp)
       (define addr (car (hash-ref label-table label)))
       (define instrs (load-immediate-number-64 rd addr tmp))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump32Absolute label rd addr-reg)
       (define addr (car (hash-ref label-table label)))
       (define instrs (jump-to-absolute-32 rd addr-reg addr))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump64Absolute label rd addr-reg tmp-reg)
       (define addr (car (hash-ref label-table label)))
       (define instrs (jump-to-absolute-64 rd addr-reg tmp-reg addr))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump32 label rd id)
       (define offset (- (car (hash-ref label-table label)) pc))
       (define instrs (generate-32-jump rd offset))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Jump64 label rd tmp id)
       (define offset (- (car (hash-ref label-table label)) pc))
       (define instrs (generate-64-jump rd offset tmp))
       (set! result (append result instrs))
       (set! pc (+ pc (* 4 (length instrs))))]

      [(Branch op label rs1 rs2)
       (define offset (- (car (hash-ref label-table label)) pc))
       (set! result
             (append result
                     (list `(,op ,offset ,rs1 ,rs2))))
       (set! pc (+ pc 4))]))

  result)

;; =========================
;; assemble
;; =========================

(define (assemble ir #:base [base 0])
  (define lowered (lower ir))
  (define jump-sizes (relax lowered base))
  (emit lowered jump-sizes base))