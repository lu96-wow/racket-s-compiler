#lang racket
;;; link/reloc.rkt
;;;
;;; relocation 记录。它由 encode 产生，由 link 消费。
;;;
;;; kind:
;;;   call-pcrel : auipc x1 + jalr x1,x1   （外部调用，固定 8 字节）
;;;   addr-pcrel : auipc reg + addi reg,reg （外部地址，固定 8 字节）
;;;   abs        : 绝对地址初值，width = 4/8

(require "../core/sexp.rkt")

(provide (struct-out relocation))

(struct relocation
  (section  ; section name（全局链）
   offset   ; section 内偏移
   kind     ; call-pcrel | addr-pcrel | abs
   symbol   ; 外部全局链
   addend
   width    ; abs 用；pcrel 固定 8
   reg)     ; (native xN) 或 #f
  #:transparent)
