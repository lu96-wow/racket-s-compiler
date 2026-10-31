#lang racket
;;; amd64/loko-compatibility/lower/ir.rkt
;;;
;;; 对 loko-ir 的 code section 执行 lower。
;;;
;;; 只改 code section 的 items；data/bss section 原样保留。
;;; 输出仍然是 loko-ir，方便后面的 image/layout-spec 消费。

(require "../ir.rkt"
         "allocate.rkt"
         "lower.rkt")

(provide lower-loko-ir)

(define (lower-loko-ir ir
                       #:available [available default-available-registers])
  (define problems '())
  (define sections
    (for/list ([section (in-list (ir-list ir 'sections))])
      (cond
        [(eq? (section-kind section) 'code)
         (define result
           (lower-program-items (section-items section) #:available available))
         (set! problems (append problems (lower-result-problems result)))
         (make-section (section-name section)
                       'code
                       (section-modes section)
                       (lower-result-items result))]
        [else section])))
  (values (make-loko-ir (ir-value ir 'origin)
                        (ir-list ir 'symbols)
                        (ir-list ir 'comms)
                        sections
                        (ir-list ir 'image-plan))
          problems))
