#lang racket
;;; amd64/loko-compatibility/mode32-table.rkt
;;;
;;; `%mode 32` 段允许的指令头固定表。
;;;
;;; 只放审计过的数据；判据要同时成立：
;;;   1. 操作数在 32 位下能由 64 位路径编码成相同字节；
;;;   2. 指令头在这张白名单里。
;;;
;;; 长模式专有指令（syscall / sysretq / swapgs / iretq / pushfq / popfq /
;;; cqo …）显式不在其中。

(provide mode32-audited-instructions)

(define mode32-audited-instructions
  '(;; 数据搬运 / 算术 / 逻辑
    mov cmp test add sub and or xor lea
    inc dec not neg shl shr sar
    movzx movsx setcc
    ;; 控制转移
    jmp-short jmp-near jcc-short jcc-near call-near
    jmp-far                                 ; 绝对远跳, 32 位下 EA+imm32+sel16
    ret nop ud2 pause
    ;; 系统 / 特权（mov crX/drX/sreg 也走上面的 mov 头）
    lgdt lidt
    rdmsr wrmsr
    in out
    cli sti hlt
    cdq                                     ; 32 位的 99；cqo 是 REX.W 版本, 不在表内
    prefix))
