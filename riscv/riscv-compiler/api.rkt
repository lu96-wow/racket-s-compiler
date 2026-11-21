#lang racket
;;; api.rkt -- riscv-compiler 对外的**最小面**。
;;;
;;; 谁该用这个文件：
;;;   - 另一个后端（riscv-core）、未来的前端（把 L0 降到 native item 的编译器）；
;;;   - 任何只想要"一条指令 -> 字节 / 一个 target 事实"的调用方。
;;;
;;; 谁不该用这个文件：
;;;   - riscv-compiler 自己的各层（它们按层依赖，见 ARCHITECTURE.md）；
;;;   - riscv-compiler-test（契约测试就是要盯着内部形状）。
;;;
;;; 规则：外部**不允许**直接 require `encode/insn.rkt`、`target.rkt`。
;;; 这样这两个模块将来搬家（例如搬到 riscv-encode/ 成为共享层）时，
;;; 只有这一个文件要改。
;;;
;;; 这里只 re-provide，不实现任何东西。

(require (only-in "encode/insn.rkt"
                  encode-instruction
                  instruction-arity
                  known-instruction?)
         (only-in "target.rkt"
                  target?
                  target-xlen
                  target-extensions
                  target-rv64-base
                  target-rv64-all
                  target-rv32-all
                  integer->bytes
                  padding-bytes))

(provide encode-instruction
         instruction-arity
         known-instruction?
         target?
         target-xlen
         target-extensions
         target-rv64-base
         target-rv64-all
         target-rv32-all
         integer->bytes
         padding-bytes)
