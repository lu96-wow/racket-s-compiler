#lang racket
;;; amd64/loko-compatibility/mode32.rkt
;;;
;;; 哪些 item 可以"用 64 位路径编码，得到和 32 位模式相同的字节"。
;;;
;;; 背景：`instruction-plan` 只接受 64 位 target（`target-64?`），本后端没有
;;; 逐 item 的模式感知编码。裸机镜像的引导段却是 `(%mode 32)`：多引导加载器
;;; 把控制权交给 32 位保护模式下的第一条指令，之后才 `jmpf` 切到长模式。
;;;
;;; 所以这里做一个**校验过的子集**，而不是默默按 64 位规则编码：
;;; 一个 32 位段里的每个 item 都必须在这里通过，否则 layout 报
;;; `mode32-unsupported-form` —— 宁可失败，也不要生成语义不同的字节。
;;;
;;; 通过判据（两条，都是"32/64 位字节相同"的必要条件）：
;;;
;;;   1. 所有寄存器操作数宽度 <= 32；内存操作数的 base/index 不能是 `rip`
;;;      或 64 位寄存器，disp 不能是 64 位。
;;;      这条挡住真正会变的形式：`push imm32`（64 位下压 8 字节）、
;;;      `mov rax, imm64`、`(mem64+ rip …)`（32 位下 mod=00 rm=101 是绝对
;;;      disp32，没有 RIP 相对）。
;;;   2. 指令头在一份**审计过的白名单**里。长模式专有指令（syscall /
;;;      sysretq / swapgs / iretq / pushfq / popfq / cqo …）显式不在其中。
;;;
;;; 白名单不是猜的：它来自 pc-repl 镜像里那 101 个 32 位 item 的实测清单
;;; （`cmp/je/jmp/mov/out/lgdt/lidt/mov crX/rdmsr/wrmsr/jmpf` + 多引导头
;;; 的数据 item），加上同族的显然安全形式。逐字节一致性由 oracle 守住：
;;; 生成结果要和 Loko 自己的 `bin/pc-repl` 对比（见 tools/）。
;;;
;;; 数据 item（label/comment/align/pad/bytes/fill/reserve/value）与模式无关。

(require "../amd64-help/cc.rkt"
         "../amd64-asm/shape.rkt"
         "../amd64-asm/memory.rkt"
         "../amd64-asm/registers.rkt"
         "../amd64-asm/operand.rkt"
         "../amd64-asm/ranges.rkt"
         "../compiler/item.rkt")

(provide mode32-compatible-item?
         mode32-audited-instructions)

;; 审计过的指令头。`canonical-cc` 别名（je/jne/…）不在这里：调用方先用
;; expand-pseudo 的 rewrite-item 把它们变成 jcc-near/jcc-short。
(define mode32-audited-instructions
  '(;; 数据搬运 / 算术 / 逻辑
    mov cmp test add sub and or xor lea
    inc dec not neg shl shr sar
    movzx movsx setcc
    ;; 控制转移
    jmp-short jmp-near jcc-short jcc-near call-near
    jmp-far                                 ; 绝对远跳, 32 位下 EA+imm32+sel16
    ret nop ud2 pause
    ;; 系统 / 特权
    lgdt lidt
    rdmsr wrmsr
    mov                                 ; mov crX/drX/sreg 也走这个头
    in out
    cli sti hlt
    cdq                                 ; 32 位的 99；cqo 是 REX.W 版本, 不在表内
    prefix))

;; 规范条件码（`jcc-near e …` 里的 e）。别名（je/jz/…）由 expand-pseudo 的
;; rewrite-item 先规范化，所以这里只需要认规范写法。
(define cc-codes '(o no b ae e ne be a s ns p np l ge le g))

(define (cc-code? x) (and (memq x cc-codes) #t))

(define (mode32-audited-instruction? name)
  (and (symbol? name) (memq name mode32-audited-instructions) #t))

;; 32 位模式下不存在的寄存器宽度: 64 位 GPR（rax…r15）。
(define (reg32-compatible? r)
  (<= (reg-width r) 32))

(define (mem32-compatible? m)
  (and (not (eq? (mem-base m) 'rip))
       (not (eq? (mem-index m) 'rip))
       (or (not (mem-base m))
           (reg32-compatible? (lookup-register (mem-base m))))
       (or (not (mem-index m))
           (reg32-compatible? (lookup-register (mem-index m))))
       ;; disp 的宽度在 32 位模式里最大 disp32
       (memq (mem-disp-width m) '(auto 32))))

(define (operand32-compatible? op)
  (cond
    [(reg? op) (reg32-compatible? op)]
    ;; 寄存器写法的符号：GPR/XMM 要求宽度 <= 32；段寄存器（`mov ds ax` 里的
    ;; ds）表里是 width 16 的 'segment；control/debug 寄存器（`mov cr4 eax`）
    ;; 的编码与操作数宽度无关，只要不是需要 REX.R 的编号即可。
    [(and (symbol? op) (lookup-register op #f))
     (define r (lookup-register op))
     (case (reg-class r)
       [(control debug) (<= (reg-index r) 7)]
       [else (reg32-compatible? r)])]
    [(mem? op) (mem32-compatible? op)]
    [(mem-form? op) (mem32-compatible? (parse-mem op))]
    [(immediate-form op)
     (and (not (eq? (immediate-form op) 'imm64))
          (operand32-compatible? (immediate-value op)))]
    ;; 符号地址：值要到 layout/encode 才知道，宽度由 64 位路径的 imm32 决定，
    ;; 32 位模式下同样是 imm32。真的相差会在 oracle 对比里暴露。
    [(and (address-expr? op) (not (exact-integer? op))) #t]
    [(exact-integer? op) (fits-any32? op)]
    [else #f]))

(define (mode32-compatible-item? item)
  (cond
    [(not (form? item)) #f]
    [(or (label-form? item) (comment-form? item) (align-form? item)
         (pad-form? item) (bytes-form? item) (fill-form? item)
         (reserve-form? item) (value-form? item))
     #t]                                     ; 数据 item: 与模式无关
    ;; 条件码指令的第一个操作数是条件码符号，不是数据操作数。
    [(memq (car item) '(jcc-short jcc-near setcc))
     (match (cdr item)
       [(list cc rest ...)
        (and (or (cc-code? cc) (canonical-cc cc))
             (andmap operand32-compatible? rest))]
       [_ #f])]
    [(eq? (car item) 'prefix)
     (and (= 3 (length item))
          (let ([inner (caddr item)])
            (and (form? inner)
                 (mode32-compatible-item? inner))))]
    [(mode32-audited-instruction? (car item))
     (andmap operand32-compatible? (cdr item))]
    [else #f]))
