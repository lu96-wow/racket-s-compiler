#lang racket/base

;; ============================================================
;; la：加载地址
;;
;; PC-relative 的情况由一个函数处理：
;;   delta 已知 -> auipc + addi
;;   delta 未知 -> 占位 auipc/addi，留 relocation
;;
;; 绝对地址直接复用 expand-li。
;; GOT / gp / frame 分别提供独立入口。
;; ============================================================

(require "instruction.rkt"
         "ranges.rkt"
         "li.rkt"
         "scratch.rkt")

;; ------------------------------------------------------------
;; PC-relative
;; ------------------------------------------------------------

;; (la-pcrel rd #:delta delta)
;;
;; delta = target - pc
;; pc    = auipc 指令地址
(define (la-pcrel rd
                  #:delta [delta #f]
                  #:word-size [word-size 'rv64])
  (cond
    [delta
     (unless (fits-pcrel-32? delta word-size)
       (error 'la-pcrel
              "PC-relative delta ~a cannot be encoded by auipc+addi"
              delta))
     (define-values (hi lo) (split-hi-lo delta))
     (list (I 'auipc rd hi)
           (I 'addi rd rd lo))]
    [else
     ;; 外部/未解析符号的占位形式。
     ;; R_RISCV_PCREL_HI20 / R_RISCV_PCREL_LO12_I 由 object 层生成。
     (list (I 'auipc rd 0)
           (I 'addi rd rd 0))]))

;; ------------------------------------------------------------
;; 绝对地址
;; ------------------------------------------------------------

;; 绝对地址和 li 共享所有范围分派。
(define (la-abs rd address
                #:word-size [word-size 'rv64]
                #:scratch [scratch #f])
  (expand-li rd address
             #:word-size word-size
             #:scratch scratch))

;; ------------------------------------------------------------
;; GOT
;; ------------------------------------------------------------

;; PIC 下加载 GOT 中的地址。
;; 这是占位形式，具体 relocation 由 object/linker 层处理。
(define (la-got rd #:word-size [word-size 'rv64])
  (define load (case word-size
                 [(rv32) 'lw]
                 [(rv64) 'ld]
                 [else (error 'la-got "unknown word size: ~a" word-size)]))
  (list (I 'auipc rd 0)
        (I load rd rd 0)))

;; ------------------------------------------------------------
;; gp-relative
;; ------------------------------------------------------------

(define (la-gp rd offset)
  (unless (fits-s12? offset)
    (error 'la-gp "gp-relative offset ~a is outside signed 12-bit range" offset))
  (list (I 'addi rd 'gp offset)))

;; ------------------------------------------------------------
;; 栈帧相对
;; ------------------------------------------------------------

;; offset 在 12 位范围内：
;;   addi rd, base, offset
;;
;; 超出范围：
;;   li tmp, offset
;;   add rd, base, tmp
(define (la-frame rd base offset
                 #:scratch [scratch #f]
                 #:word-size [word-size 'rv64])
  (cond
    [(fits-s12? offset)
     (list (I 'addi rd base offset))]
    [else
     (define tmp
       (car (take-scratch! 'la-frame (scratch-list scratch) 1)))
     (check-not-zero! 'la-frame tmp)
     (when (or (eq? tmp rd) (eq? tmp base))
       (error 'la-frame
              "scratch register ~a must differ from rd and base"
              tmp))
     (append (expand-li tmp offset #:word-size word-size)
             (list (I 'add rd base tmp)))]))

;; ------------------------------------------------------------
;; 通用组合
;; ------------------------------------------------------------

;; mode:
;;   'pcrel : value = delta 或 #f（#f 表示留 relocation）
;;   'abs   : value = 绝对地址
;;   'got   : value 忽略
;;   'gp    : value = gp-relative offset
;;   'frame : value = frame offset，必须提供 #:base
(define (expand-la rd value
                   #:mode [mode 'pcrel]
                   #:word-size [word-size 'rv64]
                   #:scratch [scratch #f]
                   #:base [base #f])
  (case mode
    [(pcrel)
     (la-pcrel rd #:delta value #:word-size word-size)]
    [(abs)
     (la-abs rd value #:word-size word-size #:scratch scratch)]
    [(got)
     (la-got rd #:word-size word-size)]
    [(gp)
     (la-gp rd value)]
    [(frame)
     (unless base
       (error 'expand-la "frame mode requires #:base"))
     (la-frame rd base value #:scratch scratch #:word-size word-size)]
    [else
     (error 'expand-la "unknown la mode: ~a" mode)]))

(provide la-pcrel
         la-abs
         la-got
         la-gp
         la-frame
         expand-la)
