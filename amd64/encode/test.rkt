#lang racket
;;; amd64/encode/test.rkt
;;;
;;; 第一版编码 golden test。只测已经实现的 form。

(require rackunit
         "insn.rkt")

(define (enc name . operands)
  (encode-instruction name operands))

(check-equal? (enc 'mov 'rax 'rbx) (bytes #x48 #x89 #xd8))
(check-equal? (enc 'mov 'rax 'rcx) (bytes #x48 #x89 #xc8))
(check-equal? (enc 'mov 'r8 'rax) (bytes #x49 #x89 #xc0))
(check-equal? (enc 'mov 'rax 'r8) (bytes #x4c #x89 #xc0))

(check-equal? (enc 'mov 'rax '(b64 (base rbp) (disp -8)))
              (bytes #x48 #x8b #x45 #xf8))
(check-equal? (enc 'mov '(b64 (base rbp) (disp -8)) 'rax)
              (bytes #x48 #x89 #x45 #xf8))
(check-equal? (enc 'mov 'rax '(b64 (base rip) (disp 0)))
              (bytes #x48 #x8b #x05 #x00 #x00 #x00 #x00))
(check-equal? (enc 'mov 'rax '(b64 (disp #x1234)))
              (bytes #x48 #x8b #x04 #x25 #x34 #x12 #x00 #x00))

(check-equal? (enc 'lea 'rax '(b64 (base rbx) (index rcx) (scale 4) (disp 8)))
              (bytes #x48 #x8d #x44 #x8b #x08))
(check-equal? (enc 'mov 'rax '(b64 (base rsp) (index rcx) (disp 0)))
              (bytes #x48 #x8b #x04 #x0c))

(check-equal? (enc 'add 'rax 8) (bytes #x48 #x83 #xc0 #x08))
(check-equal? (enc 'add 'rax 1000) (bytes #x48 #x81 #xc0 #xe8 #x03 #x00 #x00))
(check-equal? (enc 'sub 'rsp 16) (bytes #x48 #x83 #xec #x10))
(check-equal? (enc 'cmp 'rax 0) (bytes #x48 #x83 #xf8 #x00))
(check-equal? (enc 'add '(b64 (base rax) (disp 0)) 1)
              (bytes #x48 #x83 #x00 #x01))

(check-equal? (enc 'mov 'eax 1) (bytes #xb8 #x01 #x00 #x00 #x00))
(check-equal? (enc 'mov 'rax 1) (bytes #x48 #xc7 #xc0 #x01 #x00 #x00 #x00))
(check-equal? (enc 'mov 'rax #xffffffff) (bytes #xb8 #xff #xff #xff #xff))
(check-equal? (enc 'mov 'rax #x100000000) (bytes #x48 #xb8 #x00 #x00 #x00 #x00 #x01 #x00 #x00 #x00))
(check-equal? (enc 'mov 'al 1) (bytes #xb0 #x01))
(check-equal? (enc 'mov 'spl 1) (bytes #x40 #xb4 #x01))
(check-equal? (enc 'mov 'ah 1) (bytes #xb4 #x01))
(check-equal? (enc 'add 'ah 1) (bytes #x80 #xc4 #x01))

(check-equal? (enc 'push 'rax) (bytes #x50))
(check-equal? (enc 'pop 'r8) (bytes #x41 #x58))

(check-equal? (enc 'jmp-short 8) (bytes #xeb #x08))
(check-equal? (enc 'jmp-near 8) (bytes #xe9 #x08 #x00 #x00 #x00))
(check-equal? (enc 'jcc-short 'e 8) (bytes #x74 #x08))
(check-equal? (enc 'jcc-near 'e 8) (bytes #x0f #x84 #x08 #x00 #x00 #x00))
(check-equal? (enc 'call-near 8) (bytes #xe8 #x08 #x00 #x00 #x00))
(check-equal? (enc 'ret) (bytes #xc3))

(displayln "amd64 encode tests: ok")

;; size must agree with encoding
(check-equal? (instruction-size 'mov '(rax rbx)) 3)
(check-equal? (instruction-size 'add '(rax 8)) 4)
(check-equal? (instruction-size 'add '(rax 1000)) 7)
(check-equal? (instruction-size 'jmp-short '((done))) 2)
(check-equal? (instruction-size 'jmp-near '((done))) 5)
(check-equal? (instruction-size 'jcc-near '(e (done))) 6)
(check-equal? (instruction-size 'call-near '((done))) 5)
(check-equal? (instruction-size 'mov '(rax (b64 (base rbp) (disp -8)))) 4)

;; unary / test / shift / multiply / divide / extend / setcc
(check-equal? (enc 'test 'rax 'rbx) (bytes #x48 #x85 #xd8))
(check-equal? (enc 'test 'rax 1) (bytes #x48 #xf7 #xc0 #x01 #x00 #x00 #x00))
(check-equal? (enc 'inc 'rax) (bytes #x48 #xff #xc0))
(check-equal? (enc 'dec 'rax) (bytes #x48 #xff #xc8))
(check-equal? (enc 'neg 'rax) (bytes #x48 #xf7 #xd8))
(check-equal? (enc 'not 'rax) (bytes #x48 #xf7 #xd0))
(check-equal? (enc 'shl 'rax 1) (bytes #x48 #xc1 #xe0 #x01))
(check-equal? (enc 'shr 'rax 1) (bytes #x48 #xc1 #xe8 #x01))
(check-equal? (enc 'sar 'rax 1) (bytes #x48 #xc1 #xf8 #x01))
(check-equal? (enc 'imul 'rax 'rbx) (bytes #x48 #x0f #xaf #xc3))
(check-equal? (enc 'idiv 'rcx) (bytes #x48 #xf7 #xf9))
(check-equal? (enc 'div 'rcx) (bytes #x48 #xf7 #xf1))
(check-equal? (enc 'movzx 'rax 'al) (bytes #x48 #x0f #xb6 #xc0))
(check-equal? (enc 'movzx 'eax 'al) (bytes #x0f #xb6 #xc0))
(check-equal? (enc 'movsx 'rax 'al) (bytes #x48 #x0f #xbe #xc0))
(check-equal? (enc 'movsx 'rax 'eax) (bytes #x48 #x63 #xc0))
(check-equal? (enc 'setcc 'e 'al) (bytes #x0f #x94 #xc0))
(check-equal? (enc 'cqo) (bytes #x48 #x99))
(check-equal? (enc 'cdq) (bytes #x99))
