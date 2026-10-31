#lang racket
;;; amd64/encode/encode.rkt
;;;
;;; bound layout -> 每段字节。分支目标在这里换成相对偏移。
;;; 目前只支持已解析/常量内存 displacement。

(require "../sexp.rkt"
         "../target.rkt"
         "../layout/forms.rkt"
         "insn.rkt")

(provide encode-layout)

(define (field key row)
  (cond ((assq key (cdr row)) => cadr)
        [else #f]))

(define (segment-field seg key) (field key seg))
(define (segment-items seg) (cdr (assq 'items (cdr seg))))

(define (resolve-symbol symbols chain)
  (define chain* (normalize-path chain))
  (define row
    (for/first ([s (in-list symbols)]
                #:when (equal? (cadr s) chain*))
      s))
  (unless row (error 'encode "undefined symbol: ~e" chain))
  (caddr (cddr row)))

(define (resolve-address symbols expr)
  (eval-address expr (lambda (chain) (resolve-symbol symbols chain))))

(define (value->bytes width expr symbols)
  (list->bytes (integer->bytes width (resolve-address symbols expr))))

(define branch-forms '(jmp-short jmp-near jcc-short jcc-near call-near))

(define (encode-code name operands here symbols)
  (if (memq name branch-forms)
      (let* ([target (last operands)]
             [size (instruction-size name operands)]
             [address (resolve-symbol symbols target)]
             [offset (- address (+ here size))]
             [ops (append (drop-right operands 1) (list offset))])
        (encode-instruction name ops))
      (encode-instruction name operands)))

(define (encode-segment target seg symbols)
  (define name (segment-field seg 'name))
  (define kind (segment-field seg 'kind))
  (define start (segment-field seg 'start))
  (define size (segment-field seg 'size))
  (define entries (segment-items seg))
  (define chunks '())
  (define cursor 0)
  (define (emit! bs)
    (set! chunks (cons bs chunks))
    (set! cursor (+ cursor (bytes-length bs))))
  (for ([entry (in-list entries)])
    (define at (cadr entry))
    (define it (caddr entry))
    (define here (+ start at))
    (unless (= at cursor)
      (error 'encode "segment ~a offset mismatch: layout ~a, encode ~a (item ~e)"
             name at cursor it))
    (cond
      [(label-form? it) (void)]
      [(pad-form? it) (emit! (list->bytes (padding-bytes target kind (cadr it))))]
      [(bytes-form? it) (emit! (list->bytes (cdr it)))]
      [(fill-form? it) (emit! (make-bytes (cadr it) (caddr it)))]
      [(value-form? it)
       (emit! (value->bytes (value-width it) (value-payload it) symbols))]
      [else
       (emit! (encode-code (car it) (cdr it) here symbols))]))
  (list 'segment
        (list 'name name)
        (list 'kind kind)
        (list 'start start)
        (list 'size size)
        (list 'bytes (apply bytes-append (reverse chunks)))))

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
