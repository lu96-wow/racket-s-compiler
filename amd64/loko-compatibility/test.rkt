#lang racket
;;; amd64/loko-compatibility/test.rkt

(require rackunit
         "translate.rkt")

(define (field name out)
  (cdr (assq name (loko-compat-fields out))))

(define src
  '(loko-source
    (text
     (%label text)
     (mov rax (mem64+ rbp -8))
     (lea rbx (mem+ (* rcx 8) 16))
     (sal rax 1)
     (sete al)
     (cmovnc rax rbx)
     (call (mem64+ *panic))
     (jmp done)
     (%align 8)
     (%comment hello 1)
     (%label done)
     (ret))
    (data
     (%label data)
     (%u64 (+ data 8))
     (%u32 #x1234)
     (%vu8 #"\1\2\3")
     (%utf8z "hi")
     (%align 16 0)
     (%equiv answer 42)
     (%u64 answer))))

(define out (translate-loko-source src))

(check-equal? (field 'problems out) '())

(check-equal? (field 'program-items out)
              '((label text)
                (mov rax (b64 (base rbp) (disp -8)))
                (lea rbx (b64 (index rcx) (scale 8) (disp 16)))
                (shl rax 1)
                (setcc e al)
                (cmovcc ae rax rbx)
                (call-indirect (b64 (disp (*panic))))
                (jmp (done))
                (align 8)
                (comment hello 1)
                (label done)
                (ret)))

(check-equal? (field 'data-items out)
              '((label data)
                (value 8 (+ (data) 8))
                (value 4 4660)
                (bytes 1 2 3)
                (bytes 104 105 0)
                (align 16)
                (value 8 42)))

(check-equal? (field 'aliases out)
              '((alias answer 42)))

;; vector labels are stable across definition and reference
(define v (vector 'const 'x))
(define vout
  (translate-loko-source
   `(loko-source (text (%label ,v) (jmp ,v)) (data))))
(check-equal? (field 'problems vout) '())
(check-equal? (field 'program-items vout)
              '((label loko-label-0) (jmp (loko-label-0))))

;; %mem+ width is inferred from the sibling register, but not for movzx/movsx
(define wout
  (translate-loko-source
   '(loko-source (text (add rax (mem+ rbx 8))) (data))))
(check-equal? (field 'program-items wout)
              '((add rax (b64 (base rbx) (disp 8)))))

(define ambiguous
  (translate-loko-source
   '(loko-source (text (movzx rax (mem+ rbx))) (data))))
(check-true
 (for/or ([p (in-list (field 'problems ambiguous))])
   (equal? (cadr p) 'ambiguous-memory-width)))

;; directives that belong to the image/section layer are reported, not guessed
(define unsupported
  (translate-loko-source
   '(loko-source (text (%comm foo 8 8)) (data))))
(check-true
 (for/or ([p (in-list (field 'problems unsupported))])
   (equal? (cadr p) 'directive-needs-image-layer)))

(displayln "amd64 loko-compat tests: ok")

;; value references to vector labels use the same path as %label
(define v2 (vector 'const 'y))
(define vdata
  (translate-loko-source
   `(loko-source
     (text (%u64 ,v2))
     (data (%label ,v2) (%u64 (+ ,v2 8))))))
(check-equal? (field 'problems vdata) '())
(check-equal? (field 'program-items vdata)
              '((value 8 (loko-label-0))))
(check-equal? (field 'data-items vdata)
              '((label loko-label-0)
                (value 8 (+ (loko-label-0) 8))))

;; %equiv is visible to text even when it is defined in data
(define alias-order
  (translate-loko-source
   '(loko-source
     (text (%u64 answer))
     (data (%equiv answer 42)))))
(check-equal? (field 'problems alias-order) '())
(check-equal? (field 'program-items alias-order) '((value 8 42)))

;; %u128 integers become little-endian low/high value items
(define u128
  (translate-loko-source
   '(loko-source (text) (data (%u128 1)))))
(check-equal? (field 'data-items u128)
              '((value 8 1) (value 8 0)))

;; canonical conditional forms keep their condition operand
(define conds
  (translate-loko-source
   '(loko-source
     (text (jcc z done) (setcc z al) (cmovcc z rax rbx))
     (data))))
(check-equal? (field 'problems conds) '())
(check-equal? (field 'program-items conds)
              '((jcc e (done))
                (setcc e al)
                (cmovcc e rax rbx)))

;; a label named `problem` must not be confused with an internal problem
(define problem-label
  (translate-loko-source
   '(loko-source (text (jmp problem)) (data))))
(check-equal? (field 'problems problem-label) '())
(check-equal? (field 'program-items problem-label)
              '((jmp (problem))))

;; register targets are indirect too
(define indirect-reg
  (translate-loko-source
   '(loko-source (text (call rax) (jmp rbx)) (data))))
(check-equal? (field 'program-items indirect-reg)
              '((call-indirect rax) (jmp-indirect rbx)))

;; Loko's lock.* / rep.* spellings become explicit prefix forms
(define prefixed
  (translate-loko-source
   '(loko-source
     (text
      (lock.xadd (mem+ cpu-counter) ebx)
      (rep.movs (mem64+ rdi) (mem64+ rsi))
      (rep.stos (mem64+ rdi) rax)
      (rep.ins (mem+ rdi) dx)
      (rep.outs dx (mem+ rsi)))
     (data))))
(check-equal? (field 'problems prefixed) '())
(check-equal? (field 'program-items prefixed)
              '((prefix lock (xadd (b32 (disp (cpu-counter))) ebx))
                (prefix rep (movs (b64 (base rdi) (disp 0))
                                  (b64 (base rsi) (disp 0))))
                (prefix rep (stos (b64 (base rdi) (disp 0)) rax))
                (prefix rep (ins (b32 (base rdi) (disp 0)) dx))
                (prefix rep (outs dx (b32 (base rsi) (disp 0))))))

;; XMM registers are registers, not labels; SSE memory widths stay explicit
(define sse
  (translate-loko-source
   '(loko-source
     (text
      (movq xmm1 rax)
      (movss xmm2 xmm1)
      (movd xmm2 (mem32+ c_231))
      (ldmxcsr (mem32+ mxcsr-floor))
      (roundss xmm1 xmm1 #b0001)
      (xorpd xmm0 xmm0))
     (data))))
(check-equal? (field 'problems sse) '())
(check-equal? (field 'program-items sse)
              '((movq xmm1 rax)
                (movss xmm2 xmm1)
                (movd xmm2 (b32 (disp (c_231))))
                (ldmxcsr (b32 (disp (mxcsr-floor))))
                (roundss xmm1 xmm1 1)
                (xorpd xmm0 xmm0)))

;; PC control registers and descriptor tables are passes for spelling only
(define pc-system
  (translate-loko-source
   '(loko-source
     (text
      (mov cr4 eax)
      (mov rax cr2)
      (lgdt (mem+ gdtr))
      (lldt ax)
      (sysretq))
     (data))))
(check-equal? (field 'problems pc-system) '())
(check-equal? (field 'program-items pc-system)
              '((mov cr4 eax)
                (mov rax cr2)
                (lgdt (b64 (disp (gdtr))))
                (lldt ax)
                (sysretq)))
