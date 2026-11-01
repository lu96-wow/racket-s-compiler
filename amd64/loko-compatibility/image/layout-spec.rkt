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
                  label-form? label-chain comment-form? align-form?
                  make-label make-comment)
         (only-in "../../compiler/layout/forms.rkt"
                  item-size align-pad make-segment-form make-place
                  make-layout-spec)
         (only-in "plan.rkt" segment-align-for)
         "../../compiler/expand-pseudo/rewrite.rkt"
         "../mode32.rkt"
         "../ir.rkt")

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
     (cons (make-label label) items)]))

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

;; 段里的模式 run: (modes ((起始下标 模式) …))。模式是 Loko 的 %mode 指令,
;; 记录的是"从哪个 item 起换成这个模式", 一直到下一个标记。
;;
;; 本后端只有 64 位编码路径, 所以 32 位 run 只放行"用 64 位路径编码出的字节与
;; 32 位模式一致"的 item —— 判据在 loko-compatibility/mode32.rkt 里, 逐字节
;; 一致性由和 Loko 自己的 bin/pc-repl 对比来守。其余模式(16 位)仍然不支持。
(define (mode-runs modes nitems)
  (for/list ([pair (in-list modes)] [i (in-naturals)])
    (define start (car pair))
    (define end (if (< (add1 i) (length modes))
                    (car (list-ref modes (add1 i)))
                    nitems))
    (list start end (cadr pair))))

(define (check-section-modes section problem!)
  (define items (section-items section))
  (define name (section-name section))
  (for ([run (in-list (mode-runs (section-modes section) (length items)))])
    (define-values (start end mode) (apply values run))
    (case (if (exact-integer? mode) mode #f)
      [(64) (void)]
      [(32)
       (for ([item (in-list items)] [idx (in-naturals)]
             #:when (and (>= idx start) (< idx end)))
         (define rewritten (rewrite-item item #:short-transfers? #f))
         (unless (mode32-compatible-item? rewritten)
           (problem! 'mode32-unsupported-form name item)))]
      [else (problem! 'mode-unsupported name mode)])))

;; 输入:
;;   ir     loko-ir
;;   plan   解析后的 %elf 计划(可为 '()); 用来取每个 section 的对齐约束
;;
;; 输出只有"约束", 没有地址: (segment (name …) (kind …) (size …) (align …))。
;; 起点由 compiler/layout 按 (align …) 递增求解 —— 谁分配地址, 谁就该看到约束。
(define (build-layout-spec ir [plan '()])
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

  (for ([section (in-list sections)])
    (define name (section-name section))
    (define kind (section-kind section))
    (define modes (section-modes section))
    (define items (ensure-start-label section used-labels))

    (when (eq? kind 'code)
      (check-section-modes section problem!))

    (cond
      [(null? items) (void)]
      [else
       (define measured-items
         (if (eq? kind 'code)
             ;; Near forms are an upper bound; actual relax only shrinks.
             (map near-measurement-item
                  (rewrite-program items #:short-transfers? #f))
             items))
       ;; 尺寸从 0 量: 段的起点由 layout 对齐到 (align …), 而 plan 的 align
       ;; (页) 远大于段内 item 的对齐, 所以"从 0 量"和"从真实起点量"等价。
       (define size (measure-items 0 measured-items))
       (define segment-name (section-segment-name name))
       (define align (segment-align-for plan segment-name))

       (set! segments
             (cons (make-segment-form segment-name kind #:align align #:size size)
                   segments))

       (define labels (section-label-paths items))
       (when (pair? labels)
         (set! places
               (cons (make-place segment-name labels) places)))

       (case kind
         [(code) (set! program-items (append program-items items))]
         [else
          ;; Keep adjacent labels from different sections from turning
          ;; into one data unit (and thus ambiguous place rules).
          (when (pair? data-items)
            (set! data-items
                  (append data-items
                          (list (make-comment 'section-boundary segment-name)))))
          (set! data-items (append data-items items))])]))

  (values (make-layout-spec (reverse segments) (reverse places) origin)
          program-items
          data-items
          (reverse problems)))
