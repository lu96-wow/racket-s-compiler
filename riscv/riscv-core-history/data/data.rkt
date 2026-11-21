#lang racket
;;; data/data.rkt
;;;
;;; 全局 data 段的形状、校验、尺寸、字节和地址 relocation。
;;;
;;; 形状：
;;;   (data chain item ...)
;;;   item := (align n) | (bytes b ...) | (fill n b) | (value w v)
;;;   v    := 整数 | (global chain) | (+ (global chain) n)
;;;
;;; 地址初值只生成 relocation；真正的绝对地址由 program-layout 回填。
;;; 这里不处理模块可见性，也不处理函数 / 指令。

(require racket/list
         "../core/sexp.rkt"
         "../core/num.rkt")

(provide (struct-out data-relocation)
         (struct-out data-layout)
         data-form?
         data-name
         data-items
         data-align
         layout-data
         data-size
         data-bytes
         data-item-size
         address-value?
         address-value-target
         address-value-addend
         align-up)

;; 地址初值：(global chain) 或 (+ (global chain) addend)。
(struct data-relocation
  (offset   ; 段内偏移
   width    ; 4 / 8
   target   ; 全局链
   addend)  ; 整数
  #:transparent)

(struct data-layout
  (size
   align
   bytes       ; (listof byte)，地址位置先填 0
   relocations ; (listof data-relocation)
   labels)     ; hash 全局链 -> 段内偏移
  #:transparent)

;; ---------------------------------------------------------------------------
;; 形状
;; ---------------------------------------------------------------------------

(define (byte? n)
  (and (exact-integer? n) (<= 0 n 255)))

(define (address-value? v)
  (match v
    [(list 'global (? chain?)) #t]
    [(list '+ (list 'global (? chain?)) (? exact-integer?)) #t]
    [_ #f]))

(define (address-value-target v)
  (match v
    [(list 'global (? chain? chain)) chain]
    [(list '+ (list 'global (? chain? chain)) (? exact-integer?)) chain]
    [_ (error 'data "not an address value: ~e" v)]))

(define (address-value-addend v)
  (match v
    [(list 'global (? chain?)) 0]
    [(list '+ (list 'global (? chain?)) (? exact-integer? n)) n]
    [_ (error 'data "not an address value: ~e" v)]))

(define (data-width? w)
  (and (exact-integer? w) (memq w '(1 2 4 8)) #t))

(define (data-value? v)
  (or (exact-integer? v)
      (address-value? v)))

(define (data-label-item? x)
  (and (form? x)
       (eq? (car x) 'label)
       (pair? (cdr x))
       (andmap chain? (cdr x))))

(define (data-item? x)
  (match x
    [(list 'align (? power-of-two?)) #t]
    [(list 'bytes (? byte?) ...) #t]
    [(list 'fill (? exact-nonnegative-integer?) (? byte?)) #t]
    [(list 'value (? data-width? w) (? data-value? v))
     (or (exact-integer? v) (memq w '(4 8)))]
    [_ (data-label-item? x)]))

(define (valid-value-range? width value)
  (define bits (* 8 width))
  (define min (- (arithmetic-shift 1 (sub1 bits))))
  (define max (sub1 (arithmetic-shift 1 bits)))
  (<= min value max))

(define (data-form? x)
  (and (tagged? x 'data)
       (>= (length x) 2)
       (chain? (cadr x))
       (andmap data-item? (cddr x))))

(define (data-name form)
  (unless (data-form? form)
    (error 'data "malformed data: ~e" form))
  (cadr form))

(define (data-items form)
  (unless (data-form? form)
    (error 'data "malformed data: ~e" form))
  (cddr form))

;; ---------------------------------------------------------------------------
;; 对齐 / 尺寸 / 字节
;; ---------------------------------------------------------------------------

(define (data-align form)
  (unless (data-form? form)
    (error 'data "malformed data: ~e" form))
  (for/fold ([a 1]) ([item (in-list (data-items form))])
    (match item
      [(list 'align n) (max a n)]
      [_ a])))

(define (data-item-size item)
  (match item
    [(list 'align _) 0]                 ; 实际尺寸由游标决定
    [(list 'label _ ...) 0]
    [(list 'bytes bs ...) (length bs)]
    [(list 'fill n _) n]
    [(list 'value w _) w]
    [_ (error 'data "malformed data item: ~e" item)]))

(define (layout-data form)
  (unless (data-form? form)
    (error 'data "malformed data: ~e" form))
  (define-values (size bytes relocations labels)
    (layout-items (data-items form)))
  (data-layout size (data-align form) bytes relocations labels))

(define (data-size form)
  (data-layout-size (layout-data form)))

;; 只有不含地址初值的 data 才能直接取字节。
(define (data-bytes form)
  (define l (layout-data form))
  (unless (null? (data-layout-relocations l))
    (error 'data "data contains address values; use data-layout in program layout"))
  (data-layout-bytes l))

(define (layout-items items)
  (for/fold ([size 0] [bytes '()] [relocations '()] [labels (make-hash)])
            ([item (in-list items)])
    (match item
      [(list 'align n)
       (define padded (align-up size n))
       (values padded
               (append bytes (make-list (- padded size) 0))
               relocations
               labels)]

      [(list 'label chains ...)
       (for ([chain (in-list chains)])
         (when (hash-has-key? labels chain)
           (error 'data "data label ~a is defined twice"
                  (chain->string chain)))
         (hash-set! labels chain size))
       (values size bytes relocations labels)]

      [(list 'bytes bs ...)
       (values (+ size (length bs))
               (append bytes bs)
               relocations
               labels)]

      [(list 'fill n b)
       (values (+ size n)
               (append bytes (make-list n b))
               relocations
               labels)]

      [(list 'value w v)
       (cond
         [(exact-integer? v)
          (unless (valid-value-range? w v)
            (error 'data
                   "(value ~a ~a) is outside the ~a-byte range"
                   w v w))
          (define mask (sub1 (arithmetic-shift 1 (* 8 w))))
          (define value (bitwise-and v mask))
          (values (+ size w)
                  (append bytes
                          (for/list ([i (in-range w)])
                            (bitwise-and (arithmetic-shift value (- (* 8 i)))
                                         #xFF)))
                  relocations
                  labels)]

         [(address-value? v)
          (unless (memq w '(4 8))
            (error 'data "address value width must be 4 or 8: ~e" item))
          (values (+ size w)
                  (append bytes (make-list w 0))
                  (append relocations
                          (list (data-relocation size w
                                                 (address-value-target v)
                                                 (address-value-addend v))))
                  labels)]

         [else
          (error 'data "malformed value: ~e" item)])]

      [_ (error 'data "malformed data item: ~e" item)])))
