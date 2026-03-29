#lang racket

(require racket/string "build_help.rkt")

;; 构建指令文件
(define (build-riscv-instruction-file in-file out-file)
  (with-input-from-file in-file
    (λ ()
      (with-output-to-file out-file #:exists 'replace
        (λ ()
          (displayln "#lang racket")
          (displayln "(require \"../../base.rkt\"")
          (displayln "         \"../base_range.rkt\"")
          (displayln "         \"../register.rkt\")")
          (newline)

          (for ([line (in-lines)]
                [n (in-naturals 1)])
            (define trimmed (string-trim line))
            (unless (or (string=? trimmed "")
                        (string-prefix? trimmed "#")
                        (string-prefix? trimmed "$"))
              (define code (parse-instruction-line trimmed n))
              (when (not (string=? code ""))
                (displayln code))))

          (newline)
          (displayln "(provide (all-defined-out))"))))))

(provide build-riscv-instruction-file)
