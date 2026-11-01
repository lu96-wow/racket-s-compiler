#lang racket
;;; amd64/amd64-asm/test-oracle.rkt
;;;
;;; 用 LLVM MC 作为独立编码 oracle。
;;;
;;; 每个 case 是 (本后端 form . AT&T 汇编文本)。LLVM MC 给出权威字节，
;;; 本后端必须逐字节一致。没有 llvm-mc 时跳过（不阻塞本地测试）。
;;;
;;; 这里只放有代表性的 form；新增指令时先加 oracle case，再加 golden test。

(require rackunit
         racket/list
         racket/string
         racket/system
         "insn.rkt")

(define cases
  (list
   (cons '(mov rax rbx) "movq %rbx, %rax")
   (cons '(mov r8 rax) "movq %rax, %r8")
   (cons '(mov rax r8) "movq %r8, %rax")
   ;; 8-bit memory moves: 88/8A, not 89/8B.
   (cons '(mov (b8 (base rcx) (index rdi) (disp 11)) dl)
         "movb %dl, 11(%rcx,%rdi)")
   (cons '(mov dl (b8 (base rcx) (index rdi) (disp 11)))
         "movb 11(%rcx,%rdi), %dl")
   (cons '(mov (b8 (base rax) (disp 7)) al) "movb %al, 7(%rax)")
   (cons '(mov al (b8 (base rax) (disp 7))) "movb 7(%rax), %al")
   (cons '(mov (b16 (base rbp) (disp -8)) ax) "movw %ax, -8(%rbp)")
   (cons '(mov (b32 (base rax) (index r10) (scale 4) (disp 16)) ecx)
         "movl %ecx, 16(%rax,%r10,4)")
   ;; Extended index must set REX.X, not REX.B.
   (cons '(mov (b64 (base rsp) (index r10) (disp 40)) rax)
         "movq %rax, 40(%rsp,%r10)")
   (cons '(mov (b64 (base r12) (index r10) (disp 40)) rax)
         "movq %rax, 40(%r12,%r10)")
   (cons '(mov (b64 (base r13) (disp 0)) rax) "movq %rax, 0(%r13)")
   (cons '(mov rax (b64 (base rbp) (disp 0))) "movq 0(%rbp), %rax")
   ;; Absolute [disp32] and RIP-relative.
   (cons '(mov rax (b64 (disp #x1234))) "movq 0x1234, %rax")
   (cons '(mov (b64 (disp #x1234)) rax) "movq %rax, 0x1234")
   (cons '(mov rax (b64 (base rip) (disp 0))) "movq 0(%rip), %rax")
   ;; immediates
   (cons '(mov eax #x12345678) "movl $0x12345678, %eax")
   (cons '(mov rax #x1234) "movq $0x1234, %rax")
   (cons '(mov rax #x123456789) "movabsq $0x123456789, %rax")
   (cons '(add rax 1) "addq $1, %rax")
   (cons '(sub rsp 8) "subq $8, %rsp")
   (cons '(add (b64 (base rax) (disp 0)) #x1234) "addq $0x1234, (%rax)")
   (cons '(cmp (b8 (base rax) (disp 0)) 1) "cmpb $1, (%rax)")
   ;; shifts / multiply / extend
   (cons '(shl rax 3) "shlq $3, %rax")
   (cons '(shl rax cl) "shlq %cl, %rax")
   (cons '(imul rax rcx 3) "imulq $3, %rcx, %rax")
   (cons '(movzx eax dl) "movzbl %dl, %eax")
   (cons '(movsx rax eax) "movslq %eax, %rax")
   ;; condition codes / setcc / cmovcc
   (cons '(setcc e al) "sete %al")
   (cons '(cmovcc e rax rbx) "cmoveq %rbx, %rax")
   ;; lea / test / push-pop
   (cons '(lea rax (b64 (base rbx) (index rcx) (scale 4) (disp 8)))
         "leaq 8(%rbx,%rcx,4), %rax")
   (cons '(test rax rax) "testq %rax, %rax")
   (cons '(push rax) "pushq %rax")
   (cons '(pop rax) "popq %rax")
   ;; SSE / XMM
   (cons '(movss xmm1 (b32 (base rax))) "movss (%rax), %xmm1")
   (cons '(addss xmm1 xmm2) "addss %xmm2, %xmm1")
   (cons '(movd xmm1 eax) "movd %eax, %xmm1")
   (cons '(movdqa xmm1 (b128 (base rax))) "movdqa (%rax), %xmm1")
   (cons '(xorpd xmm1 xmm2) "xorpd %xmm2, %xmm1")
   ;; NASM-generated table families (adc/sbb/shld/bit ops/SSE2/CRC32)
   (cons '(adc rax rbx) "adcq %rbx, %rax")
   (cons '(adc rax 1) "adcq $1, %rax")
   (cons '(adc rax 200) "adcq $200, %rax")
   (cons '(sbb al 1) "sbbb $1, %al")
   (cons '(adc ah 1) "adcb $1, %ah")
   (cons '(adc spl 1) "adcb $1, %spl")
   (cons '(adc (b8 (base r12) (disp 3)) r9b) "adcb %r9b, 3(%r12)")
   (cons '(shld rax rbx 3) "shldq $3, %rbx, %rax")
   (cons '(shld rax rbx cl) "shldq %cl, %rbx, %rax")
   (cons '(bt rax 3) "btq $3, %rax")
   (cons '(btc rax rbx) "btcq %rbx, %rax")
   (cons '(bts (b64 (base rax)) rbx) "btsq %rbx, (%rax)")
   (cons '(bt (b64 (base r12) (index r10) (scale 8) (disp 16)) 7)
         "btq $7, 16(%r12,%r10,8)")
   (cons '(movbe rax (b64 (base rbx))) "movbeq (%rbx), %rax")
   (cons '(movbe r8 (b64 (base r13))) "movbeq (%r13), %r8")
   (cons '(lzcnt ax cx) "lzcntw %cx, %ax")
   (cons '(tzcnt r8 r9) "tzcntq %r9, %r8")
   (cons '(addsd xmm1 xmm2) "addsd %xmm2, %xmm1")
   (cons '(paddq xmm1 xmm2) "paddq %xmm2, %xmm1")
   (cons '(movapd xmm1 xmm2) "movapd %xmm2, %xmm1")
   (cons '(movdqu xmm1 (b128 (base rsp))) "movdqu (%rsp), %xmm1")
   (cons '(cvtsi2sd xmm1 rax) "cvtsi2sdq %rax, %xmm1")
   (cons '(crc32 rax rbx) "crc32q %rbx, %rax")
   (cons '(crc32 eax (b8 (base rbx))) "crc32b (%rbx), %eax")
   (cons '(cmpxchg8b (b64 (base rax))) "cmpxchg8b (%rax)")
   (cons '(xgetbv) "xgetbv")
   (cons '(rdpkru) "rdpkru")
   (cons '(verr ax) "verr %ax")
   (cons '(verw (b16 (base rax))) "verw (%rax)")
   (cons '(monitor) "monitor")
   (cons '(invlpg (b64 (base rax))) "invlpg (%rax)")
   ;; system / special registers
   (cons '(mov cr3 rax) "movq %rax, %cr3")
   (cons '(mov rax cr3) "movq %cr3, %rax")
   (cons '(lgdt (b64 (base rax))) "lgdt (%rax)")))

(define llvm-mc (find-executable-path "llvm-mc"))
(unless llvm-mc
  (displayln "llvm-mc not found; skipping amd64 encoding oracle")
  (exit 0))

(define source
  (let ([p (make-temporary-file "amd64-oracle-~a.s")])
    (call-with-output-file p #:exists 'replace
      (lambda (out)
        (for ([c (in-list cases)])
          (displayln (cdr c) out))))
    p))
(define output
  (with-output-to-string
    (lambda () (system* llvm-mc "-triple=x86_64" "-show-encoding" source))))
(delete-file source)

(define encodings
  (for/list ([line (in-list (string-split output "\n"))]
             #:when (string-contains? line "# encoding: ["))
    (define encoded (cadr (string-split line "# encoding: [")))
    (define bytes-text (car (string-split encoded "]")))
    (for/list ([h (in-list (string-split bytes-text #px"[,\\s]+" #:trim? #t))]
               #:unless (string=? h ""))
      (string->number (substring h 2) 16))))

(check-equal? (length encodings) (length cases) "llvm-mc did not encode every case")
(for ([c (in-list cases)] [expected (in-list encodings)])
  (define form (car c))
  (check-equal? (bytes->list (encode-instruction (car form) (cdr form)))
                expected
                (format "encoding mismatch for ~a (`~a`)" form (cdr c))))

(displayln "amd64 encoding oracle tests: ok")
