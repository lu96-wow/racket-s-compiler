#lang racket
;;; amd64/loko-compatibility/test.rkt

(require rackunit
         "translate.rkt"
         "mode32.rkt")

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
   '(loko-source (text (%call foo)) (data))))
(check-true
 (for/or ([p (in-list (field 'problems unsupported))])
   (equal? (cadr p) 'directive-needs-image-layer)))

;; `$` is the current item address; it stays symbolic until layout/bind.
(define current-ip
  (translate-loko-source
   '(loko-source (text (mov rax (mem+ ($))) (%u64 ($))) (data))))
(check-equal? (field 'problems current-ip) '())
(check-equal? (field 'program-items current-ip)
              '((mov rax (b64 (disp $)))
                (value 8 $)))

;; symbolic bit operations stay symbolic until layout/bind/encode
(define symbolic-bits
  (translate-loko-source
   '(loko-source
     (text)
     (data
      (%u64 (bitwise-ior (data) 1))
      (%u64 (<< (data) 4))
      (%u64 (>> (data) 4))))))
(check-equal? (field 'problems symbolic-bits) '())
(check-equal? (field 'data-items symbolic-bits)
              '((value 8 (bitwise-ior (data) 1))
                (value 8 (ash (data) 4))
                (value 8 (ash (data) (- 0 4)))))

;; %label start end: end is symbol metadata, not an alias at start's address.
(define label-end
  (translate-loko-source
   '(loko-source
     (text (%label start end 7) (mov rax 1) (%label end) (ret))
     (data (%label d)))))
(check-equal? (field 'problems label-end) '())
(check-equal? (field 'program-items label-end)
              '((label start) (mov rax 1) (label end) (ret)))
(check-equal? (field 'symbols label-end)
              '((symbol (start) (end) text (7))
                (symbol (end) (end) text ())
                (symbol (d) (d) data ())))

;; %section / %origin / %mode are captured into ordered section runs.
(define sectioned
  (translate-loko-source
   '(loko-source
     (text
      (%origin #x200000)
      (%mode 32)
      (%section text)
      (%label text)
      (mov rax 1)
      (%mode 64)
      (%section data)
      (%label d)
      (%u64 1))
     (data
      (%section bss)
      (%label b)))))
(check-equal? (field 'problems sectioned) '())
(check-equal? (field 'origin sectioned) '(#x200000))
(check-equal? (field 'program-items sectioned)
              '((label text) (mov rax 1)))
(check-equal? (field 'data-items sectioned)
              '((label d) (value 8 1) (label b)))
(check-equal? (field 'symbols sectioned)
              '((symbol (text) (text) text ())
                (symbol (d) (d) data ())
                (symbol (b) (b) bss ())))
(check-equal? (field 'sections sectioned)
              '((section (name text) (kind code) (modes (0 32) (2 64))
                         (items (label text) (mov rax 1)))
                (section (name data) (kind data) (modes)
                         (items (label d) (value 8 1)))
                (section (name bss) (kind hole) (modes)
                         (items (label b)))))

;; %init-bss is a frontend marker: only explicit source gets zeroing code.
(define init-bss
  (translate-loko-source
   '(loko-source
     (text
      (%mode 64)
      (%section text)
      (%label text)
      (%init-bss)
      (ret))
     (data))))
(check-equal? (field 'problems init-bss) '())
(check-equal? (field 'program-items init-bss)
              '((label text)
                (cld)
                (li rdi (bss))
                (li rcx (bss-end))
                (sub rcx rdi)
                (xor eax eax)
                (prefix rep (stos (b8 (base rdi) (disp 0)) al))
                (ret)))

(define init-bss-custom
  (translate-loko-source
   '(loko-source
     (text
      (%mode 64)
      (%label text)
      (%init-bss bss-start bss-stop)
      (ret))
     (data))))
(check-equal? (field 'problems init-bss-custom) '())
(check-equal? (field 'program-items init-bss-custom)
              '((label text)
                (cld)
                (li rdi (bss-start))
                (li rcx (bss-stop))
                (sub rcx rdi)
                (xor eax eax)
                (prefix rep (stos (b8 (base rdi) (disp 0)) al))
                (ret)))

(define init-bss-32
  (translate-loko-source
   '(loko-source
     (text (%mode 32) (%label text) (%init-bss) (ret))
     (data))))
(check-true
 (for/or ([p (in-list (field 'problems init-bss-32))])
   (eq? (cadr p) 'init-bss-mode-unsupported)))

(define init-bss-data
  (translate-loko-source
   '(loko-source
     (text (%mode 64) (%section data) (%init-bss) (ret))
     (data))))
(check-true
 (for/or ([p (in-list (field 'problems init-bss-data))])
   (eq? (cadr p) 'init-bss-not-in-code)))

;; %comm is collected, sorted by size, and expanded at the bss section.
(define comms
  (translate-loko-source
   '(loko-source
     (text
      (%comm large 4096 4096)
      (%comm small 8 8)
      (%section text)
      (%label text)
      (ret))
     (data
      (%label bss)
      (%section bss)
      (%label bss-end)))))
(check-equal? (field 'problems comms) '())
(check-equal? (field 'comms comms)
              '((comm (large) 4096 4096)
                (comm (small) 8 8)))
(check-equal? (field 'program-items comms)
              '((label text) (ret)))
(check-equal? (field 'data-items comms)
              '((label bss)
                (align 8) (label small) (reserve 8)
                (align 4096) (label large) (reserve 4096)
                (label bss-end)))
(check-equal? (field 'sections comms)
              '((section (name text) (kind code) (modes)
                         (items (label text) (ret)))
                (section (name data) (kind data) (modes)
                         (items (label bss)))
                (section (name bss) (kind hole) (modes)
                         (items
                          (align 8) (label small) (reserve 8)
                          (align 4096) (label large) (reserve 4096)
                          (label bss-end)))))

(define comm-without-bss
  (translate-loko-source
   '(loko-source
     (text (%comm foo 8 8) (%label text) (ret))
     (data))))
(check-true
 (for/or ([p (in-list (field 'problems comm-without-bss))])
   (eq? (cadr p) 'comm-without-bss-section)))

;; %comm names can be vector labels (pc-segments uses this).
(define comm-vector (vector 'comm 'x))
(define comm-with-vector
  (translate-loko-source
   `(loko-source
     (text (%comm ,comm-vector 8 8) (%label text) (ret))
     (data (%label bss) (%section bss) (%label bss-end)))))
(check-equal? (field 'problems comm-with-vector) '())
(check-equal? (field 'comms comm-with-vector)
              '((comm (loko-label-0) 8 8)))

;; %elf is captured as an explicit image-plan.
(define elf-plan
  (translate-loko-source
   '(loko-source
     (text
      (%elf
       (entry text)
       (load (id text) (align 4096))
       (load (id data) (align 4096))
       (load (id bss) (align 4096))
       (region (id text) (content materialized) (section .text)
               (perm r-x) (align 16) (load text))
       (region (id data) (content materialized) (section .data)
               (perm rw-) (align 8) (load data))
       (region (id bss) (content reserved) (section .bss)
               (perm rw-) (align 8) (load bss))
       (symbol (name text) (region text) (size 1)
               (type func) (bind global))))
     (data))))
(check-equal? (field 'problems elf-plan) '())
(check-equal? (field 'image-plan elf-plan)
              '((entry (text))
                (load (id text) (align 4096))
                (load (id data) (align 4096))
                (load (id bss) (align 4096))
                (region (id text) (content materialized) (section .text)
                        (perm r-x) (align 16) (load text))
                (region (id data) (content materialized) (section .data)
                        (perm rw-) (align 8) (load data))
                (region (id bss) (content reserved) (section .bss)
                        (perm rw-) (align 8) (load bss))
                (symbol (name (text)) (region text) (size 1)
                        (type func) (bind global))))

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

;; ---------------------------------------------------------------------------
;; ELF writer 的产出: %call / %elf-header / %elf-tail
;;
;; 汇编期的 %call 是闭包(拿 assemble!/ip/symbols 直接发 item), 不可序列化,
;; 它的三处用途全是 ELF writer。dump 用两个标记把那两段标出来, 前端只负责丢:
;; 镜像头由 image 层重新生成, 尾部之后没有任何程序内容。
;; ---------------------------------------------------------------------------

(define elf-wrapped
  (translate-loko-source
   '(loko-source
     (text
      (%origin #x200000)
      (%label image-address-zero)
      (%elf-header)                 ; ELF header + program headers: 丢掉
      (%utf8z "hi")
      (%section text)
      (%label main)
      (ret)
      (%elf-tail)                   ; segments/symtab/strtab: 之后全部截断
      (%section elf)
      (%u8 127) (%u8 69) (%u8 76) (%u8 70))
     (data))))

(check-equal? (field 'problems elf-wrapped) '())
(check-equal? (field 'program-items elf-wrapped)
              '((label image-address-zero) (bytes 104 105 0) (label main) (ret)))
(check-equal? (field 'data-items elf-wrapped) '())
;; 汇编期的 elf 段(ELF 尾)没有进来; data 段是空占位
(check-equal? (map (lambda (s) (cadr (assq 'name (cdr s))))
                   (field 'sections elf-wrapped))
              '(text data))
(check-equal? (field 'program-items elf-wrapped)
              (field 'program-items
                     (translate-loko-source
                      '(loko-source
                        (text
                         (%origin #x200000)
                         (%label image-address-zero)
                         (%utf8z "hi")
                         (%section text)
                         (%label main)
                         (ret))
                        (data)))))

;; 没被标记过的 %call 仍然报问题: 那说明输入还带着汇编期的 ELF writer
(define raw-call
  (translate-loko-source
   '(loko-source
     (text (%label main) (ret) (%call some-procedure))
     (data))))
(check-true
 (for/or ([p (in-list (field 'problems raw-call))])
   (eq? (cadr p) 'directive-needs-image-layer)))

;; ---------------------------------------------------------------------------
;; 裸机 (pc) 写法: 远跳、段寄存器、符号 u128
;; ---------------------------------------------------------------------------

;; (jmpf (far 选择子 目标)) -> (jmp-far 选择子 目标): 偏移是绝对地址表达式,
;; 尺寸固定 7 字节(EA + imm32 + sel16), 不参与 relax。
(define far-jump
  (translate-loko-source
   '(loko-source
     (text (%label begin) (jmpf (far 8 begin)) (jmpf (far 24 begin)))
     (data))))
(check-equal? (field 'program-items far-jump)
              '((label begin) (jmp-far 8 (begin)) (jmp-far 24 (begin))))

;; 段寄存器写成单元素路径 (mov (ds) ax) 时归一成寄存器写法
(define segment-move
  (translate-loko-source
   '(loko-source
     (text (%label t) (mov (ds) ax) (mov (es) ax) (mov fs ax) (ret))
     (data))))
(check-equal? (field 'program-items segment-move)
              '((label t) (mov ds ax) (mov es ax) (mov fs ax) (ret)))

;; 符号 %u128 拆成两个 8 字节 value(低位在前), 交给 layout 求值:
;; IDT 门描述符就是"handler 地址 + 选择子 + 类型位"。
(define symbolic-u128
  (translate-loko-source
   '(loko-source
     (text (%label t))
     (data (%label gate) (%u128 (bitwise-ior gate 8 #x8e00))))))
(check-equal? (field 'data-items symbolic-u128)
              '((label gate)
                (value 8 (bitwise-and (bitwise-ior (gate) 8 36352) 18446744073709551615))
                (value 8 (ash (bitwise-ior (gate) 8 36352) -64))))

;; ---------------------------------------------------------------------------
;; 32 位模式子集: 用 64 位路径编码是否等价
;;
;; 裸机引导段是 (%mode 32)。本后端只有 64 位编码路径, 所以只放行"字节相同"的
;; item; 下面就是那份判据的正反例。
;; ---------------------------------------------------------------------------

(define (mode32-ok? item) (mode32-compatible-item? item))

;; pc-repl 引导段实际出现的形态: 全部必须放行
(for ([item (in-list '((mov eax 16)
                       (mov al 0)
                       (cmp eax 732803074)
                       (jmp-near (loko-obj-vector-0))
                       (jcc-near e (loko-obj-vector-0))
                       (mov ds ax)
                       (jmp-far 8 (multiboot:start64))
                       (lgdt (b64 (disp (gdtr32))))
                       (lidt (b64 (disp (idtr32))))
                       (mov cr4 eax)
                       (mov eax cr0)
                       (rdmsr)
                       (wrmsr)
                       (out 128 al)
                       (label start)                 ; 数据 item 与模式无关
                       (value 4 (bss))))])
  (unless (mode32-ok? item)
    (fail "32 位模式下应当放行: ~e" item)))

;; 这些在 32 位下语义/编码不同, 必须拦下
(for ([item (in-list '((push 5)                      ; 64 位下压 8 字节
                       (mov rax 5)                   ; r64
                       (mov rax 8589934592)          ; imm64
                       (mov (b64 (base rax)) r15)    ; 需要 REX
                       (mov rax (b64 (base rip) (disp 0))) ; 32 位没有 RIP 相对
                       (syscall)                     ; 长模式专有
                       (sysretq)
                       (swapgs)
                       (cqo)
                       (cmpxchg (b64 (base rax)) rbx)))])  ; 未审计
  (when (mode32-ok? item)
    (fail "32 位模式下应当拒绝: ~e" item)))
