#lang racket
;;; amd64/loko-compatibility/image/layout-spec.rkt
;;;
;;; loko-ir -> compiler 的 layout-spec。
;;;
;;; 输入是 translate.rkt 产出的 loko-ir：
;;;
;;;   (loko-ir (origin #x200000)
;;;            (symbols ...)
;;;            (comms ...)
;;;            (sections (section ...) ...))
;;;
;;; 输出：
;;;
;;;   layout-spec        compiler 的 segments/place 形式
;;;   program-items      code section 的扁平 item（含 section 起始 label）
;;;   data-items         data/bss section 的扁平 item
;;;   problems           当前无法安全生成的布局问题
;;;
;;; 这一层只做“section 顺序 -> 地址顺序”的粗布局：
;;;   - 以 origin 为起点，按 section 顺序累加；
;;;   - 用近分支（near）测量 code 段，得到安全上界；
;;;   - 真正的 short/near 选择仍由 compiler 的 expand-pseudo + relax 完成；
;;;   - 每个 section 开头补一个内部 label，保证 block/data run 能命中 place。
;;;
;;; 因此 code section 的实际大小可能小于这里测得的 size；后续段起点会保留
;;; 上界 gap，但不会溢出。等以后有更完整的 layout 预量层时再收紧。

(require "../../amd64-asm/sexp.rkt"
         "../../amd64-asm/target.rkt"
         "../ir.rkt"
         (only-in "../../compiler/item.rkt"
                  label-form? label-chain comment-form? align-form?)
         (only-in "../../compiler/layout/forms.rkt"
                  item-size align-pad)
         "../../compiler/expand-pseudo/rewrite.rkt")

(provide build-layout-spec)

(define (section-segment-name name)
  (if (symbol? name)
      name
      (string->symbol (format "~a" name))))

(define (section-label-paths items)
  (remove-duplicates
   (for/list ([item (in-list items)] #:when (label-form? item))
     (label-chain item))))

(define (all-label-paths sections)
  (remove-duplicates
   (append* (for/list ([section (in-list sections)])
              (section-label-paths (section-items section))))))

(define (fresh-section-label section-name used)
  (let loop ([n 0])
    (define base (if (zero? n)
                     (format "loko-image-start-~a" section-name)
                     (format "loko-image-start-~a-~a" section-name n)))
    (define path (list (string->symbol base)))
    (if (hash-ref used path #f)
        (loop (add1 n))
        (begin
          (hash-set! used path #t)
          path))))

(define (ensure-start-label section used)
  (define items (section-items section))
  (cond
    [(null? items) items]
    [(label-form? (car items)) items]
    [else
     (define label (fresh-section-label (section-name section) used))
     (cons (cons 'label label) items)]))

(define (near-measurement-item item)
  ;; Explicit short forms can still be relaxed later; measure their near
  ;; upper bound.
  (cond
    [(and (form? item) (eq? (car item) 'jmp-short))
     (list 'jmp-near (cadr item))]
    [(and (form? item) (eq? (car item) 'jcc-short))
     (list 'jcc-near (cadr item) (caddr item))]
    [else item]))

(define (measure-items start items)
  (for/fold ([cursor 0]) ([item (in-list items)])
    (cond
      [(align-form? item)
       (+ cursor (align-pad (+ start cursor) (cadr item)))]
      [(or (label-form? item) (comment-form? item))
       cursor]
      [else
       (+ cursor (item-size target-amd64 item))])))

(define (unsupported-modes modes)
  (for/list ([mode (in-list modes)]
             #:when (not (= (cadr mode) 64)))
    (cadr mode)))

(define (build-layout-spec ir)
  (define origin (or (ir-value ir 'origin) 0))
  (define sections (ir-list ir 'sections))
  (define used-labels (make-hash))
  (for ([path (in-list (all-label-paths sections))])
    (hash-set! used-labels path #t))
  (define problems '())
  (define (problem! kind . detail)
    (set! problems (cons (cons 'problem (cons kind detail)) problems)))

  (define segments '())
  (define places '())
  (define program-items '())
  (define data-items '())
  (define cursor origin)

  (for ([section (in-list sections)])
    (define name (section-name section))
    (define kind (section-kind section))
    (define modes (section-modes section))
    (define items (ensure-start-label section used-labels))

    (define bad-modes (unsupported-modes modes))
    (when (and (eq? kind 'code) (pair? bad-modes))
      (for ([mode (in-list bad-modes)])
        (problem! 'mode-unsupported name mode)))

    (cond
      [(null? items) (void)]
      [else
       (define measured-items
         (if (eq? kind 'code)
             ;; Near forms are an upper bound; actual relax only shrinks.
             (map near-measurement-item
                  (rewrite-program items #:short-transfers? #f))
             items))
       (define size (measure-items cursor measured-items))
       (define end (+ cursor size))
       (define segment-name (section-segment-name name))

       (set! segments
             (cons (list 'segment
                         (list 'name segment-name)
                         (list 'kind kind)
                         (list 'start cursor)
                         (list 'end end)
                         (list 'align 1))
                   segments))

       (define labels (section-label-paths items))
       (when (pair? labels)
         (set! places
               (cons (cons 'place (cons segment-name labels)) places)))

       (case kind
         [(code) (set! program-items (append program-items items))]
         [else
          ;; Keep adjacent labels from different sections from turning
          ;; into one data unit (and thus ambiguous place rules).
          (when (pair? data-items)
            (set! data-items
                  (append data-items
                          (list (list 'comment 'section-boundary segment-name)))))
          (set! data-items (append data-items items))])

       (set! cursor end)]))

  (values (cons (cons 'segments (reverse segments))
                (reverse places))
          program-items
          data-items
          (reverse problems)))
