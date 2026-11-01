#lang racket
;;; amd64/compiler/encode/encode.rkt
;;;
;;; bound layout -> 每段字节。分支目标在这里换成相对偏移。
;;; 目前只支持已解析/常量内存 displacement。
;;;
;;; 两种段两条路径: code/data 逐条落字节; kind = hole 的段只有地址没有字节,
;;; 产物是 (size n) + (bytes #"")。洞里的内容不归本产物定义。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-asm/target.rkt"
         "../item.rkt"
         "../../amd64-asm/insn.rkt")

(provide encode-layout)

(define (field-value key row)
  (cond ((assq key (cdr row)) => cadr)
        [else #f]))

(define (segment-field seg key) (field-value key seg))
(define (segment-items seg) (cdr (assq 'items (cdr seg))))

(define (resolve-symbol symbols chain)
  (define chain* (normalize-path chain))
  (define row
    (for/first ([s (in-list symbols)]
                #:when (equal? (cadr s) chain*))
      s))
  (unless row (error 'encode "undefined symbol: ~e" chain))
  (caddr (cddr row)))

(define (resolve-address symbols expr here)
  (eval-address expr (lambda (chain) (resolve-symbol symbols chain)) here))

(define (value->bytes width expr symbols here)
  (list->bytes (integer->bytes width (resolve-address symbols expr here))))

(define control-transfer-forms '(jmp-short jmp-near jcc-short jcc-near call-near))

(define (resolve-mem m here size symbols)
  (define d (mem-disp m))
  (define resolved
    (cond
      [(exact-integer? d) d]
      [(eq? (mem-base m) 'rip)
       (- (resolve-address symbols d here) (+ here size))]
      [else (resolve-address symbols d here)]))
  (struct-copy mem m [disp resolved]))

(define (resolve-operand op here size symbols)
  (cond
    [(mem? op) (resolve-mem op here size symbols)]
    [(mem-form? op) (resolve-mem (parse-mem op) here size symbols)]
    ;; Prepared immediate wrapper whose payload is still symbolic.
    [(and (immediate-form op)
          (symbolic-immediate? (cadr op)))
     (list (immediate-form op) (resolve-address symbols (cadr op) here))]
    [(and (address-expr? op) (not (exact-integer? op)))
     (list 'imm32 (resolve-address symbols op here))]
    [else op]))

(define (encode-code target name operands here symbols)
  (cond
    [(eq? name 'prefix)
     (unless (and (= 2 (length operands)) (form? (cadr operands)))
       (error 'encode "bad prefix form: ~e" (cons name operands)))
     (define pname (car operands))
     (define inner (cadr operands))
     ;; The prefix byte shifts the inner instruction by one byte, so
     ;; RIP-relative operands inside it use here+1 and the inner size.
     (define inner-size (instruction-size target (car inner) (cdr inner)))
     (define prepared (choose-symbolic-immediate-forms (car inner) (cdr inner)))
     (define inner* (cons (car inner)
                          (map (lambda (op) (resolve-operand op (+ here 1) inner-size symbols))
                               prepared)))
     (encode-instruction target 'prefix (list pname inner*))]

    [(memq name control-transfer-forms)
     (let* ([target-operand (last operands)]
            [size (instruction-size target name operands)]
            [address (resolve-symbol symbols target-operand)]
            [offset (- address (+ here size))]
            [ops (append (drop-right operands 1) (list offset))])
       (encode-instruction target name ops))]

    [else
     (let* ([prepared (choose-symbolic-immediate-forms name operands)]
            [size (instruction-size target name operands)]
            [ops (map (lambda (op) (resolve-operand op here size symbols))
                      prepared)])
       (encode-instruction target name ops))]))

;; (offset k ...) is an assertion: by the time we reach this item the position
;; must be exactly k.  Both segment paths share it, so their errors cannot drift.
(define (check-offset! name at reached it)
  (unless (= at reached)
    (error 'encode "segment ~a offset mismatch: layout ~a, encode ~a (item ~e)"
           name at reached it)))

;; A hole segment has an address range but no file bytes; the segment's size is
;; kept, the bytes are empty.  What lives there is defined by the loader, the
;; program or the hardware -- not by this artifact, so encode does not
;; materialize anything and does not care who zeroes it.
;; Items can only be label / reserve (layout already turned align into reserve).
(define (encode-hole-segment seg)
  (define name (segment-field seg 'name))
  (define size (segment-field seg 'size))
  (define cursor 0)                     ; memory-only: there is no file cursor here
  (for ([entry (in-list (segment-items seg))])
    (define at (cadr entry))
    (define it (caddr entry))
    (check-offset! name at cursor it)
    (cond
      [(label-form? it) (void)]
      [(reserve-form? it) (set! cursor (+ cursor (reserve-size it)))]
      [else (error 'encode
                   "hole segment ~a got an item that writes bytes: ~e"
                   name it)]))
  (unless (= cursor size)
    (error 'encode "segment ~a size mismatch: layout says ~a, hole advances ~a"
           name size cursor))
  (list 'segment
        (list 'name name)
        (list 'kind 'hole)
        (list 'start (segment-field seg 'start))
        (list 'size size)
        (list 'bytes #"")))

(define (encode-materialized-segment target seg symbols)
  (define name (segment-field seg 'name))
  (define kind (segment-field seg 'kind))
  (define start (segment-field seg 'start))
  (define size (segment-field seg 'size))
  (define entries (segment-items seg))
  (let ([chunks '()]
        [cursor 0])
    (define (emit! bs)
      (set! chunks (cons bs chunks))
      (set! cursor (+ cursor (bytes-length bs))))
    (for ([entry (in-list entries)])
      (define at (cadr entry))
      (define it (caddr entry))
      (define here (+ start at))
      (check-offset! name at cursor it)
      (cond
        [(label-form? it) (void)]
        [(pad-form? it) (emit! (list->bytes (padding-bytes target kind (cadr it))))]
        [(bytes-form? it) (emit! (list->bytes (cdr it)))]
        [(fill-form? it) (emit! (make-bytes (cadr it) (caddr it)))]
        [(reserve-form? it)
         (error 'encode "reserve is only valid in a hole segment: ~e" it)]
        [(value-form? it)
         (emit! (value->bytes (value-width it) (value-payload it) symbols here))]
        [else
         (define expect (instruction-size target (car it) (cdr it)))
         (define bs (encode-code target (car it) (cdr it) here symbols))
         (unless (= expect (bytes-length bs))
           (error 'encode
                  "item size mismatch at ~a/~a: layout ~a, encode ~a: ~e"
                  name at expect (bytes-length bs) it))
         (emit! bs)]))
    (unless (= cursor size)
      (error 'encode "segment ~a size mismatch: layout says ~a, encoder wrote ~a"
             name size cursor))
    (list 'segment
          (list 'name name)
          (list 'kind kind)
          (list 'start start)
          (list 'size size)
          (list 'bytes (apply bytes-append (reverse chunks))))))

;; Two kinds of segments, two paths: materialized ones emit bytes item by item,
;; hole ones only advance the position.  "Where the hole starts" is not a
;; runtime state -- the segment declares it.
(define (encode-segment target seg symbols)
  (if (eq? (segment-field seg 'kind) 'hole)
      (encode-hole-segment seg)
      (encode-materialized-segment target seg symbols)))
(define (encode-layout target layout)
  (define requests (cdr (or (assq 'requests layout) '(requests))))
  (unless (null? requests)
    (error 'encode-layout "layout still has requests: ~e" requests))
  (define problems (cdr (or (assq 'problems layout) '(problems))))
  (unless (null? problems)
    (error 'encode-layout "layout still has problems: ~e" problems))
  (define symbols (cdr (assq 'symbols layout)))
  (define segments (cdr (assq 'segments layout)))
  (cons 'build
        (for/list ([seg (in-list segments)])
          (encode-segment target seg symbols))))
