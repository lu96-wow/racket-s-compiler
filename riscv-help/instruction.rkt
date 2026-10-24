#lang racket/base

;; ============================================================
;; 指令表示
;;
;; 这里只描述“要生成什么指令”，不负责编码。
;; size 显式保存，因为 RVC 指令是 2 字节，普通指令是 4 字节。
;; ============================================================

(struct insn (name args size)
  #:transparent)

(define (I name . args)
  (insn name args 4))

(define (I16 name . args)
  (insn name args 2))

(define (insns-size insns)
  (for/sum ([i (in-list insns)])
    (insn-size i)))

(provide (struct-out insn)
         I
         I16
         insn-size
         insns-size)
