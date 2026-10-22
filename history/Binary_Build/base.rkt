#lang racket

;; (bit-range a b c d) — 从[a,b]移到[c,d]; (bit-range x y) — 从位x移到位y
(define-syntax bit-range
  (syntax-rules ()
    [(_ a b c d)
     (let* ([low-src (min a b)]
            [high-src (max a b)]
            [low-dst (min c d)]
            [high-dst (max c d)]
            [width (add1 (- high-src low-src))]
            [mask (sub1 (arithmetic-shift 1 width))]
            [src-mask (arithmetic-shift mask low-src)])
       (lambda (v)
         (let* ([field (bitwise-and v src-mask)]
                [shifted-to-zero (arithmetic-shift field (- low-src))]
                [final (arithmetic-shift shifted-to-zero low-dst)])
           final)))]
    [(_ x y)
     (lambda (v)
       (arithmetic-shift (bitwise-and (arithmetic-shift v (- x)) 1) y))]))

;; (bit-range-fixed a b val) — 将val低(b-a+1)位写入[a,b],无论a和b顺序如何
(define-syntax bit-range-fixed
  (syntax-rules ()
    [(_ a b val)
     (let* ([small (min a b)]
            [big (max a b)]
            [h (add1 (- big small))])
       (lambda (_)
         (arithmetic-shift (bitwise-and val (sub1 (arithmetic-shift 1 h))) small)))]))

;; (bit-range-split f1 f2 ...) — 合并多个动态位域(同输入变量)
(define-syntax bit-range-split
  (syntax-rules ()
    [(_ f) (lambda (v) (f v))]
    [(_ f g ...) (lambda (v)
                   (bitwise-ior (f v)
                                ((bit-range-split g ...) v)))]))

;; (bit-range-fixed-split f1 f2 ... val) — 用val作为输入,合并多个(bit-range ...)函数结果
(define-syntax bit-range-fixed-split
  (syntax-rules ()
    [(_ f val) (lambda (_) (f val))]
    [(_ f g ... val)
     (lambda (_)
       (bitwise-ior (f val)
                    ((bit-range-fixed-split g ... val) 0)))]))

;; (make-instruction dyn1 dyn2 ... (bit-range-fixed-split ... val))
;; 示例: (make-instruction (bit-range 0 3 4 7) (bit-range-fixed-split (bit-range 0 1 2 3) #b11))
(define-syntax make-instruction
  (syntax-rules ()
    [(_ f) (lambda args
             (if (null? args)
                 (f 0)
                 (f (car args))))]
    [(_ f g ...)
     (lambda args
       (if (null? args)
           (bitwise-ior (f 0)
                        (apply (make-instruction g ...) '()))
           (bitwise-ior (f (car args))
                        (apply (make-instruction g ...) (cdr args)))))]))

(provide bit-range bit-range-fixed bit-range-split bit-range-fixed-split make-instruction)