#lang racket

(require racket/match
         "riscv-help.rkt")

(provide assemble
         (struct-out AssembleResult)
         Instruction Label
         Jump32 Jump64
         Jump32Absolute Jump64Absolute
         Branch
         LoadImm32 LoadImm64
         LoadAddress32 LoadAddress64
         Hole)

;; =========================
;; 返回结构（已扩展）
;; =========================

(struct AssembleResult (forms abs-symbols rel-symbols) #:transparent)

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

       [(list 'jump32 name) (make-jump32 name)]
       [(list 'jump32 name rd) (make-jump32 name rd)]
       [(list 'jump64 name rd tmp) (make-jump64 name rd tmp)]

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
;; 符号表构建（分离）
;; =========================

(define (build-abs-symbol-table label-table)
  (for/list ([(name addrs) (in-hash label-table)])
    `(label ,name ,(reverse addrs))))

(define (build-rel-symbol-table label-table base)
  (for/list ([(name addrs) (in-hash label-table)])
    `(label ,name
            ,(map (lambda (a) (- a base))
                  (reverse addrs)))))

;; =========================
;; compute-labels
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

      [(LoadImm32 rd imm)
       (set! pc (+ pc (* 4 (length (load-immediate-number-32 rd imm)))))]

      [(LoadImm64 rd imm tmp)
       (set! pc (+ pc (* 4 (length (load-immediate-number-64 rd imm tmp)))))]

      [(LoadAddress32 rd label)
       (define addr (safe-first-label label))
       (set! pc (+ pc (* 4 (length (load-immediate-number-32 rd addr)))))]

      [(LoadAddress64 rd label tmp)
       (define addr (safe-first-label label))
       (set! pc (+ pc (* 4 (length (load-immediate-number-64 rd addr tmp)))))]

      [(Jump32Absolute label rd addr-reg)
       (define addr (safe-first-label label))
       (set! pc (+ pc (* 4 (length (jump-to-absolute-32 rd addr-reg addr)))))]

      [(Jump64Absolute label rd addr-reg tmp-reg)
       (define addr (safe-first-label label))
       (set! pc (+ pc (* 4 (length (jump-to-absolute-64 rd addr-reg tmp-reg addr)))))]

      [(Branch _ _ _ _)
       (set! pc (+ pc 4))]))

  table)

;; =========================
;; relax（不变）
;; =========================

(define (relax ir base)
  (define jump-size-table (make-hash))

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
        [(Hole size) (set! pc (+ pc size))]
        [(Instruction forms)
         (set! pc (+ pc (* 4 (length forms))))]

        [(Jump32 label rd id)
         (define offset (- (car (hash-ref label-table label)) pc))
         (define new-size (length (generate-32-jump rd offset)))
         (when (not (= new-size (hash-ref jump-size-table id)))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        [(Jump64 label rd tmp id)
         (define offset (- (car (hash-ref label-table label)) pc))
         (define new-size (length (generate-64-jump rd offset tmp)))
         (when (not (= new-size (hash-ref jump-size-table id)))
           (hash-set! jump-size-table id new-size)
           (set! changed #t))
         (set! pc (+ pc (* 4 new-size)))]

        [else
         (set! pc (+ pc
                     (match node
                       [(Branch _ _ _ _) 4]
                       [_ (* 4 (length (list node)))])))]))

    (when changed (loop)))

  jump-size-table)

;; =========================
;; emit（不变）
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
       (set! result
             (append result
                     (make-list (quotient size 4)
                                '(addi x0 x0 0))))
       (set! pc (+ pc size))]

      [(LoadImm32 rd imm)
       (define i (load-immediate-number-32 rd imm))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(LoadImm64 rd imm tmp)
       (define i (load-immediate-number-64 rd imm tmp))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(LoadAddress32 rd label)
       (define addr (car (hash-ref label-table label)))
       (define i (load-immediate-number-32 rd addr))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(LoadAddress64 rd label tmp)
       (define addr (car (hash-ref label-table label)))
       (define i (load-immediate-number-64 rd addr tmp))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(Jump32 label rd id)
       (define offset (- (car (hash-ref label-table label)) pc))
       (define i (generate-32-jump rd offset))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(Jump64 label rd tmp id)
       (define offset (- (car (hash-ref label-table label)) pc))
       (define i (generate-64-jump rd offset tmp))
       (set! result (append result i))
       (set! pc (+ pc (* 4 (length i))))]

      [(Branch op label rs1 rs2)
       (define offset (- (car (hash-ref label-table label)) pc))
       (set! result (append result (list `(,op ,offset ,rs1 ,rs2))))
       (set! pc (+ pc 4))]))

  result)

;; =========================
;; assemble（最终）
;; =========================

(define (assemble ir
                  #:base [base 0]
                  #:gen-abs-symbols? [gen-abs? #f]
                  #:gen-rel-symbols? [gen-rel? #f])

  (define lowered (lower ir))
  (define jump-sizes (relax lowered base))
  (define label-table (compute-labels lowered jump-sizes base))

  (define forms (emit lowered jump-sizes base))

  (define abs-symbols
    (and gen-abs?
         (build-abs-symbol-table label-table)))

  (define rel-symbols
    (and gen-rel?
         (build-rel-symbol-table label-table base)))

  (AssembleResult forms abs-symbols rel-symbols))