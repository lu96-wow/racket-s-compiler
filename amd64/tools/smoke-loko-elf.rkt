#lang racket
;;; amd64/tools/smoke-loko-elf.rkt
;;;
;;; 冒烟测试: 一段 Loko 源码 -> `elf` 流程 -> ELF64 -> 真的执行它。
;;;
;;; 为什么要有它: 单元测试只检查产物"形状对不对", 而曾经出现过形状全对、
;;; 但镜像一执行就 SIGSEGV 的情况 —— .text 和 .bss 落在同一页, 内核的
;;; 匿名 RW 页把代码页盖掉了。能执行一次才说明布局/装载是对的。
;;;
;;; 只在 Linux x86-64 上真跑; 其它平台只构建不执行。

(require rackunit
         racket/file
         racket/port
         racket/system
         "../loko-compatibility/flow.rkt"
         "../amd64-asm/target.rkt")

;; 最小的 Loko 程序: write(1, "hi\n", 3) 之后 exit(42)。
;; 只用到 mov / syscall, 不依赖 Loko 运行时, 也不依赖 stack/heap 区域的内容。
(define smoke-source
  '(loko-source
    (text
     (%origin #x200000)
     (%mode 64)
     (%section text)
     (%label elf-entry)
     ;; write(1, msg, 3)
     (mov rax 1)
     (mov rdi 1)
     (li rsi (msg))
     (mov rdx 3)
     (syscall)
     ;; exit(42)
     (mov rax 60)
     (mov rdi 42)
     (syscall))
    (data
     (%section data)
     (%label msg)
     (%u8 104) (%u8 105) (%u8 10)
     (%section bss)
     (%label bss)
     (reserve 16)
     (%label bss-end))))

(define image (compile-image target-amd64 (list (cons 'loko-source smoke-source)) 'elf))
(define bytes (cadr (assq 'bytes (cdr image))))

(check-true (> (bytes-length bytes) 0))
(check-equal? (subbytes bytes 0 4) #"\x7fELF")
(check-equal? (cadr (assq 'entry (cdr image))) #x200000)

;; 段必须按页分开: 这是上面的 SIGSEGV 的直接原因, 也是本测试要守住的东西。
(define starts
  (for/list ([s (in-list (cdr (assq 'sections (cdr image))))]
             #:when (memq (cadr (assq 'type (cdr s))) '(progbits nobits))
             #:unless (zero? (cadr (assq 'size (cdr s)))))
    (cadr (assq 'addr (cdr s)))))
(check-equal? (length (remove-duplicates (map (lambda (a) (quotient a 4096)) starts)))
              (length starts)
              "每个非空 section 必须落在自己的 4K 页上")

(define (run-image!)
  (define path (make-temporary-file "loko-smoke-~a" #f))
  (call-with-output-file path #:exists 'truncate (lambda (out) (write-bytes bytes out)))
  (file-or-directory-permissions path #o755)
  ;; (subprocess stdout stdin stderr cmd …) -> (values proc stdout stdin stderr)
  (define-values (proc out _in _err) (subprocess #f #f #f path))
  (define printed (port->string out))       ; 顺便把子进程的 stdout 收干净
  (subprocess-wait proc)
  (define code (subprocess-status proc))
  (delete-file path)
  (when (non-empty-string? printed) (eprintf "smoke: 程序输出 ~s\n" printed))
  code)

(define (x86-64-unix?)
  (define machine (system-type 'machine))
  (and (eq? (system-type) 'unix)
       (string? machine)
       (regexp-match? #rx"x86_64" machine)))

(if (x86-64-unix?)
    (check-equal? (run-image!) 42 "镜像必须能执行并退出 42")
    (displayln "smoke: 不是 x86_64 unix, 只构建不执行"))

(displayln "amd64 loko-elf smoke tests: ok")
