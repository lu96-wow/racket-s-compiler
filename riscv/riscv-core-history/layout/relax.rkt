#lang racket
;;; layout/relax.rkt
;;;
;;; 第一版 layout-relax：
;;;   - 按 layout-plan 的顺序铺 block；
;;;   - jump / branch / call-target / addr-global / return / trap；
;;;   - 近形式直接发；远形式先做 inline 展开；
;;;   - 迭代到固定点。
;;;
;;; islands 还没有实现；policy 里保留字段。当前默认 far-branch/far-jump 用 inline。

(require racket/list
         "../../riscv-help/ranges.rkt"
         "../core/sexp.rkt"
         "../ir/shape.rkt"
         "../ir/li.rkt"
         "../ir/scratch.rkt"
         "../asm/code.rkt"
         "policy.rkt"
         "plan.rkt")

(provide (struct-out layout-result)
         layout-func
         layout-result->sexp)

;; items:
;;   (label name)
;;   (insn form)
;;   (branch mnemonic rs1 rs2 target)
;;   (jump target)
;;   (far-jump target)            ; auipc scratch + jalr x0
;;   (call-target (global chain)) ; symbolic, 8 bytes
;;   (addr-global (native xN) (global chain)) ; symbolic, 8 bytes
;;   (return)
;;   (trap)

(struct layout-result
  (frame
   scratch
   items
   scratch-request) ; 0 / 1
  #:transparent)

(define (layout-result->sexp result)
  (list 'layout
        (layout-result-frame result)
        (cons 'scratch (layout-result-scratch result))
        (cons 'items (layout-result-items result))
        (list 'scratch-request (layout-result-scratch-request result))))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

(define (layout-func func plan
                     #:policy [policy default-layout-policy]
                     #:xlen [xlen 64])
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'layout "expected a func: ~e" func))
  (unless (layout-plan? plan)
    (error 'layout "expected a layout-plan: ~e" plan))
  (unless (policy-valid? policy)
    (error 'layout "invalid layout policy: ~e" policy))
  (when (layout-policy-rvc? policy)
    (error 'layout "RVC layout is not implemented yet"))
  (unless (memq xlen '(32 64))
    (error 'layout "xlen must be 32 or 64: ~e" xlen))
  (define far-branch (layout-policy-far-branch policy))
  (define far-jump (layout-policy-far-jump policy))
  (for ([mode (in-list (list far-branch far-jump))])
    (case mode
      [(inline islands) (void)]
      [(indirect)
       (error 'layout "indirect far form is not implemented yet")]
      [else
       (error 'layout "unknown far form policy: ~e" mode)]))
  (define islands?
    (or (eq? far-branch 'islands) (eq? far-jump 'islands)))
  (when (and islands? (not (and (eq? far-branch 'islands)
                                (eq? far-jump 'islands))))
    (error 'layout
           "mixed island/inline policy is not implemented yet: ~e"
           policy))

  (define body (cddr func))
  (define frame
    (findf (lambda (x) (and (form? x) (eq? (car x) 'frame))) body))
  (unless frame
    (error 'layout "func ~a: missing frame" (chain->string (cadr func))))
  (define scratch (func-scratch func 'layout))

  (define block-forms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'block))) body))
  (define block-names (map cadr block-forms))
  (for ([name (in-list (layout-plan-order plan))])
    (unless (member name block-names)
      (error 'layout "plan block ~a is not declared" name)))

  (define scratch-used? (box #f))
  (define final-items
    (if islands?
        (let-values ([(resolved edge-island)
                      (resolve-islands
                       (build-islands-items func plan block-forms
                                            xlen scratch scratch-used?)
                       block-names)])
          (emit-islands-items resolved edge-island))
        (let* ([initial-items
                (build-items func plan block-forms xlen scratch scratch-used?)]
               [relaxed-items (relax-items initial-items block-names)])
          (emit-items relaxed-items scratch xlen scratch-used?))))

  (unless (or (not (unbox scratch-used?)) (pair? scratch))
    (raise-scratch-exhausted 'layout))

  (layout-result frame
                 scratch
                 final-items
                 (if (unbox scratch-used?) 1 0)))

;; ---------------------------------------------------------------------------
;; 初始 items
;; ---------------------------------------------------------------------------

(define (build-items func plan block-forms xlen scratch scratch-used?)
  (define order (layout-plan-order plan))
  (define block-table
    (for/hash ([block (in-list block-forms)])
      (values (cadr block) block)))

  (append*
   (for/list ([block-name (in-list order)]
              [index (in-naturals)])
     (define block (hash-ref block-table block-name #f))
     (unless block (error 'layout "missing block ~a" block-name))
     (define next
       (and (< (add1 index) (length order))
            (list-ref order (add1 index))))
     (define forms (cddr block))
     (define term (last forms))
     (define ops (drop-right forms 1))
     (append
      (list (list 'label block-name))
      (append* (for/list ([op (in-list ops)])
                 (op->items op)))
      (term->items term next xlen scratch scratch-used?)))))

(define (op->items op)
  (define head (car op))
  (case head
    [(call) (error 'layout "unlowered call remains: ~e" op)]
    [(call-target) (list (list 'call-target (cadr op)))]
    [(asm-code) (list (list 'asm-code (cdr op)))]
    [(addr)
     (unless (global-ref? (caddr op))
       (error 'layout "addr source must be (global chain) after lower-ops: ~e" op))
     (list (list 'addr-global (cadr op) (caddr op)))]
    [(asm) (error 'layout "inline asm is not lowered: ~e" op)]
    [else (list (list 'insn op))]))

(define (term->items term next xlen scratch scratch-used?)
  (match (cadr term)
    [(list 'jump (? symbol? target))
     (if (eq? target next)
         '()
         (list (list 'jump target)))]

    [(list 'branch condition (? symbol? then-block) (? symbol? else-block))
     (cond
       [(eq? then-block else-block)
        (if (eq? next then-block)
            '()
            (list (list 'jump then-block)))]
       [(eq? next then-block)
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'branch (invert-mnemonic mnemonic)
                              rs1 rs2 else-block))))]
       [(eq? next else-block)
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'branch mnemonic rs1 rs2 then-block))))]
       [else
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'branch mnemonic rs1 rs2 then-block)
                        (list 'jump else-block))))])]

    [(list 'return)
     (list (list 'return))]
    [(list 'return _ ...)
     (error 'layout "return still has operands; run call-lower first: ~e" term)]
    [(list 'trap)
     (list (list 'trap))]
    [_ (error 'layout "malformed term: ~e" term)]))

;; ---------------------------------------------------------------------------
;; islands
;; ---------------------------------------------------------------------------
;; 只在 far-branch = far-jump = islands 时使用。
;; 不拆基本块；slot 只出现在非 fallthrough 的 block 边界和函数末尾。

(define (build-islands-items func plan block-forms xlen scratch scratch-used?)
  (define order (layout-plan-order plan))
  (define fallthrough (layout-plan-fallthrough plan))
  (define block-table
    (for/hash ([block (in-list block-forms)])
      (values (cadr block) block)))
  (define edge-counter (box 0))
  (define slot-counter (box 0))

  (define (next-edge-id!)
    (begin0 (unbox edge-counter)
      (set-box! edge-counter (add1 (unbox edge-counter)))))
  (define (next-slot-id!)
    (begin0 (unbox slot-counter)
      (set-box! slot-counter (add1 (unbox slot-counter)))))

  (append
   (append*
    (for/list ([block-name (in-list order)]
               [index (in-naturals)])
      (define block (hash-ref block-table block-name #f))
      (unless block (error 'layout "missing block ~a" block-name))
      (define prev (and (> index 0) (list-ref order (sub1 index))))
      (define next
        (and (< (add1 index) (length order))
             (list-ref order (add1 index))))
      (define slot?
        (and prev (not (eq? (hash-ref fallthrough prev #f) block-name))))
      (define forms (cddr block))
      (define term (last forms))
      (define ops (drop-right forms 1))
      (append
       (if slot? (list (list 'slot (next-slot-id!))) '())
       (list (list 'label block-name))
       (append* (for/list ([op (in-list ops)])
                  (op->items op)))
       (term->islands-items term next block-name xlen scratch scratch-used?
                            next-edge-id!))))
   (list (list 'slot (next-slot-id!)))))

(define (term->islands-items term next block-name xlen scratch scratch-used?
                             next-edge-id!)
  (match (cadr term)
    [(list 'jump (? symbol? target))
     (if (eq? target next)
         '()
         (list (list 'edge-jump (next-edge-id!) block-name target)))]

    [(list 'branch condition (? symbol? then-block) (? symbol? else-block))
     (cond
       [(eq? then-block else-block)
        (if (eq? next then-block)
            '()
            (list (list 'edge-jump (next-edge-id!) block-name then-block)))]
       [(eq? next then-block)
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'edge-branch (next-edge-id!) block-name
                              (invert-mnemonic mnemonic)
                              rs1 rs2 else-block))))]
       [(eq? next else-block)
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'edge-branch (next-edge-id!) block-name
                              mnemonic rs1 rs2 then-block))))]
       [else
        (let-values ([(mnemonic rs1 rs2 pre)
                      (branch-condition condition xlen scratch scratch-used?)])
          (append pre
                  (list (list 'edge-branch (next-edge-id!) block-name
                              mnemonic rs1 rs2 then-block)
                        (list 'edge-jump (next-edge-id!) block-name else-block))))])]

    [(list 'return)
     (list (list 'return))]
    [(list 'return _ ...)
     (error 'layout "return still has operands; run call-lower first: ~e" term)]
    [(list 'trap)
     (list (list 'trap))]
    [_ (error 'layout "malformed term: ~e" term)]))

(define (edge-item? item)
  (and (form? item)
       (memq (car item) '(edge-branch edge-jump))))

(define (edge-item-id item)
  (cadr item))

(define (edge-item-block item)
  (caddr item))

(define (edge-item-target item)
  (last item))

(define (edge-branch-item? item)
  (eq? (car item) 'edge-branch))

(define (resolve-islands base-items block-names)
  (define edge-items
    (for/hash ([item (in-list base-items)]
               #:when (edge-item? item))
      (values (edge-item-id item) item)))
  (define slot-islands (make-hash))
  (define edge-island (make-hash))
  (define used-labels (make-hash))
  (for ([name (in-list block-names)]) (hash-set! used-labels name #t))
  (define island-counter (box 0))

  (define (fresh-island-label!)
    (let loop ()
      (define n (unbox island-counter))
      (set-box! island-counter (add1 n))
      (define name (string->symbol (format "island-~a" n)))
      (cond
        [(hash-has-key? used-labels name) (loop)]
        [else
         (hash-set! used-labels name #t)
         name])))

  (define (insert-islands items)
    (append*
     (for/list ([item (in-list items)])
       (if (eq? (car item) 'slot)
           (append (list item)
                   (for/list ([pair (in-list (hash-ref slot-islands (cadr item) '()))])
                     (list 'island (car pair) (cadr pair))))
           (list item)))))

  (define (scan-islands items)
    (define labels (make-hash))
    (define edge-offsets (make-hash))
    (define island-offsets (make-hash))
    (define slots '())
    (define offset 0)
    (for ([item (in-list items)])
      (case (car item)
        [(label)
         (define name (cadr item))
         (when (hash-has-key? labels name)
           (error 'layout "label ~a is defined twice" name))
         (hash-set! labels name offset)]
        [(slot)
         (set! slots (append slots (list (list (cadr item) offset))))]
        [(edge-branch edge-jump)
         (hash-set! edge-offsets (edge-item-id item) offset)
         (set! offset (+ offset 4))]
        [(island)
         (hash-set! island-offsets (cadr item) offset)
         (set! offset (+ offset 4))]
        [(insn) (set! offset (+ offset 4))]
        [(call-target) (set! offset (+ offset 8))]
        [(addr-global) (set! offset (+ offset 8))]
        [(asm-code) (set! offset (+ offset (asm-code-size (cadr item))))]
        [(return) (set! offset (+ offset 4))]
        [(trap) (set! offset (+ offset 4))]
        [else (error 'layout "unknown island layout item: ~e" item)]))
    (values labels edge-offsets island-offsets slots))

  (define (near-edge? item source-offset labels)
    (define target (edge-item-target item))
    (define target-offset (hash-ref labels target #f))
    (unless target-offset
      (error 'layout "edge target ~a has no label" target))
    (define delta (- target-offset source-offset))
    (if (edge-branch-item? item)
        (fits-branch? delta)
        (fits-jal? delta)))

  (let loop ([round 0])
    (when (> round 10000)
      (error 'layout "island layout did not converge"))
    (define items (insert-islands base-items))
    (define-values (labels edge-offsets island-offsets slots)
      (scan-islands items))

    ;; 已分配的 island 必须仍然可达；第一版不做链，也不重新分配。
    (for ([(edge-id island-label) (in-hash edge-island)])
      (define item (hash-ref edge-items edge-id))
      (define source-offset (hash-ref edge-offsets edge-id))
      (define island-offset (hash-ref island-offsets island-label #f))
      (define target (edge-item-target item))
      (define target-offset (hash-ref labels target #f))
      (unless (and island-offset target-offset)
        (error 'layout "internal: island label or target disappeared"))
      (define to-island (- island-offset source-offset))
      (define to-target (- target-offset island-offset))
      (unless (if (edge-branch-item? item)
                  (fits-branch? to-island)
                  (fits-jal? to-island))
        (error 'layout
               "island for block ~a -> ~a is no longer reachable from its source"
               (edge-item-block item) target))
      (unless (fits-jal? to-target)
        (error 'layout
               "island for block ~a -> ~a cannot reach target; island chain is not implemented"
               (edge-item-block item) target)))

    ;; 找第一个仍然 far 且还没有 island 的 edge。
    (define pending
      (for/or ([item (in-list base-items)]
                  #:when (edge-item? item)
                  #:unless (hash-has-key? edge-island (edge-item-id item)))
        (define id (edge-item-id item))
        (define source-offset (hash-ref edge-offsets id))
        (and (not (near-edge? item source-offset labels)) item)))

    (cond
      [pending
       (define edge-id (edge-item-id pending))
       (define source-offset (hash-ref edge-offsets edge-id))
       (define target (edge-item-target pending))
       (define target-offset (hash-ref labels target))
       (define slot-choice
         (for/or ([slot (in-list slots)])
           (define slot-id (car slot))
           (define slot-offset (cadr slot))
           (define existing (length (hash-ref slot-islands slot-id '())))
           (define island-offset (+ slot-offset (* 4 existing)))
           (define to-island (- island-offset source-offset))
           (define to-target (- target-offset island-offset))
           (and (if (edge-branch-item? pending)
                    (fits-branch? to-island)
                    (fits-jal? to-island))
                (fits-jal? to-target)
                slot-id)))
       (unless slot-choice
         (define range (if (edge-branch-item? pending) "±4KiB" "±1MiB"))
         (error 'layout
                "islands: ~a from block ~a to ~a is far, but no reachable slot (~a); split the source block or use inline policy"
                (if (edge-branch-item? pending) "branch" "jump")
                (edge-item-block pending) target range))
       (define label (fresh-island-label!))
       (hash-set! edge-island edge-id label)
       (hash-set! slot-islands slot-choice
                  (append (hash-ref slot-islands slot-choice '())
                          (list (list label target))))
       (loop (add1 round))]

      [else
       (values items edge-island)])))

(define (emit-islands-items items edge-island)
  (append*
   (for/list ([item (in-list items)])
     (case (car item)
       [(slot) '()]
       [(label) (list item)]
       [(island)
        (list (list 'label (cadr item))
              (list 'jal '(native x0) (caddr item)))]
       [(edge-branch)
        (define dest (hash-ref edge-island (cadr item) (edge-item-target item)))
        (list (list (cadddr item) dest (list-ref item 4) (list-ref item 5)))]
       [(edge-jump)
        (define dest (hash-ref edge-island (cadr item) (edge-item-target item)))
        (list (list 'jal '(native x0) dest))]
       [(insn) (list (cadr item))]
       [(call-target) (list item)]
       [(addr-global) (list item)]
       [(asm-code) (list item)]
       [(return) (list (list 'jalr '(native x0) '(native x1) 0))]
       [(trap) (list (list 'ebreak))]
       [else (error 'layout "unknown island item in emit: ~e" item)]))))

;; ---------------------------------------------------------------------------
;; 条件
;; ---------------------------------------------------------------------------

(define (branch-condition condition xlen scratch scratch-used?)
  (match condition
    [(list 'eq a b) (condition-items 'beq a b xlen scratch scratch-used?)]
    [(list 'ne a b) (condition-items 'bne a b xlen scratch scratch-used?)]
    [(list 'lt a b) (condition-items 'blt a b xlen scratch scratch-used?)]
    [(list 'le a b) (condition-items 'bge b a xlen scratch scratch-used?)]
    [(list 'ltu a b) (condition-items 'bltu a b xlen scratch scratch-used?)]
    [(list 'leu a b) (condition-items 'bgeu b a xlen scratch scratch-used?)]
    [_ (error 'layout "malformed condition: ~e" condition)]))

(define (condition-items mnemonic a b xlen scratch scratch-used?)
  (define pool (make-scratch-pool scratch))
  (define-values (ra aops) (condition-operand a xlen pool scratch-used?))
  (define-values (rb bops) (condition-operand b xlen pool scratch-used?))
  (values mnemonic ra rb (append aops bops)))

(define (condition-operand operand xlen pool scratch-used?)
  (cond
    [(physical-register? operand) (values operand '())]
    [(eqv? operand 0) (values '(native x0) '())]
    [(exact-integer? operand)
     (set-box! scratch-used? #t)
     (define s (take-scratch! pool))
     (values s
             (for/list ([inst (in-list (emit-li s operand xlen))])
               (list 'insn inst)))]
    [else (error 'layout "unsupported condition operand: ~e" operand)]))

(define (invert-mnemonic mnemonic)
  (case mnemonic
    [(beq) 'bne]
    [(bne) 'beq]
    [(blt) 'bge]
    [(bge) 'blt]
    [(bltu) 'bgeu]
    [(bgeu) 'bltu]
    [else (error 'layout "not a branch mnemonic: ~a" mnemonic)]))

;; ---------------------------------------------------------------------------
;; 松弛
;; ---------------------------------------------------------------------------

(define (item-size item)
  (case (car item)
    [(label) 0]
    [(insn) 4]
    [(branch) 4]
    [(jump) 4]
    [(far-jump) 8]
    [(call-target) 8]
    [(addr-global) 8]
    [(asm-code) (asm-code-size (cadr item))]
    [(slot) 0]
    [(edge-branch) 4]
    [(edge-jump) 4]
    [(island) 4]
    [(return) 4]
    [(trap) 4]
    [else (error 'layout "unknown layout item: ~e" item)]))

(define (compute-offsets items)
  (define table (make-hash))
  (define offset 0)
  (for ([item (in-list items)])
    (case (car item)
      [(label)
       (define name (cadr item))
       (when (hash-has-key? table name)
         (error 'layout "label ~a is defined twice" name))
       (hash-set! table name offset)]
      [else (set! offset (+ offset (item-size item)))]))
  (values table offset))

(define (relax-items items block-names)
  (define counter (box 0))
  (define used-labels (make-hash))
  (for ([name (in-list block-names)]) (hash-set! used-labels name #t))

  (let loop ([items items] [round 0])
    (when (> round 1000)
      (error 'layout "layout relaxation did not converge"))
    (define-values (offsets _total) (compute-offsets items))
    (define changed? (box #f))
    (define new-items
      (relax-once items offsets block-names counter used-labels changed?))
    (if (unbox changed?)
        (loop new-items (add1 round))
        items)))

(define (relax-once items offsets block-names counter used-labels changed?)
  (define offset 0)
  (append*
   (for/list ([item (in-list items)])
     (case (car item)
       [(label)
        (list item)]

       [(jump)
        (define target (cadr item))
        (define target-offset (hash-ref offsets target #f))
        (unless target-offset
          (error 'layout "jump target ~a has no label" target))
        (define delta (- target-offset offset))
        (set! offset (+ offset (item-size item)))
        (if (fits-jal? delta)
            (list item)
            (begin
              (set-box! changed? #t)
              (list (list 'far-jump target))))]

       [(branch)
        (define mnemonic (cadr item))
        (define rs1 (caddr item))
        (define rs2 (cadddr item))
        (define target (car (cddddr item)))
        (define target-offset (hash-ref offsets target #f))
        (unless target-offset
          (error 'layout "branch target ~a has no label" target))
        (define delta (- target-offset offset))
        (set! offset (+ offset (item-size item)))
        (if (fits-branch? delta)
            (list item)
            (let ([skip (fresh-label block-names counter used-labels)])
              (set-box! changed? #t)
              (list (list 'branch (invert-mnemonic mnemonic) rs1 rs2 skip)
                    (list 'jump target)
                    (list 'label skip))))]

       [(far-jump)
        (set! offset (+ offset (item-size item)))
        (list item)]

       [(call-target)
        (set! offset (+ offset (item-size item)))
        (list item)]

       [(addr-global)
        (set! offset (+ offset (item-size item)))
        (list item)]

       [(asm-code)
        (set! offset (+ offset (item-size item)))
        (list item)]

       [(return) (set! offset (+ offset (item-size item))) (list item)]
       [(trap) (set! offset (+ offset (item-size item))) (list item)]
       [(insn) (set! offset (+ offset (item-size item))) (list item)]
       [else (error 'layout "unknown item: ~e" item)]))))

(define (fresh-label block-names counter used-labels)
  (let loop ()
    (define n (unbox counter))
    (set-box! counter (add1 n))
    (define name (string->symbol (format "relax-far-~a" n)))
    (cond
      [(or (member name block-names) (hash-has-key? used-labels name))
       (loop)]
      [else
       (hash-set! used-labels name #t)
       name])))

;; ---------------------------------------------------------------------------
;; 输出
;; ---------------------------------------------------------------------------

(define (emit-items items scratch xlen scratch-used?)
  (define-values (offsets _total) (compute-offsets items))
  (define offset 0)
  (append*
   (for/list ([item (in-list items)])
     (case (car item)
       [(label)
        (list item)]

       [(insn)
        (set! offset (+ offset 4))
        (list (cadr item))]

       [(branch)
        (define mnemonic (cadr item))
        (define rs1 (caddr item))
        (define rs2 (cadddr item))
        (define target (car (cddddr item)))
        (set! offset (+ offset 4))
        (list (list mnemonic target rs1 rs2))]

       [(jump)
        (define target (cadr item))
        (set! offset (+ offset 4))
        (list (list 'jal '(native x0) target))]

       [(far-jump)
        (define target (cadr item))
        (define target-offset (hash-ref offsets target #f))
        (unless target-offset
          (error 'layout "far-jump target ~a has no label" target))
        (set! scratch-used? #t)
        (unless (pair? scratch)
          (raise-scratch-exhausted 'layout))
        (define s (car scratch))
        (define delta (- target-offset offset))
        (define-values (hi lo) (split-hi-lo delta))
        (set! offset (+ offset 8))
        (list (list 'auipc s hi)
              (list 'jalr '(native x0) s lo))]

       [(call-target)
        (set! offset (+ offset 8))
        (list item)]

       [(addr-global)
        (set! offset (+ offset 8))
        (list item)]

       [(asm-code)
        (set! offset (+ offset (asm-code-size (cadr item))))
        (list item)]

       [(return)
        (set! offset (+ offset 4))
        (list (list 'jalr '(native x0) '(native x1) 0))]

       [(trap)
        (set! offset (+ offset 4))
        (list (list 'ebreak))]

       [else (error 'layout "unknown item: ~e" item)]))))

;; ---------------------------------------------------------------------------
;; scratch pool
;; ---------------------------------------------------------------------------

