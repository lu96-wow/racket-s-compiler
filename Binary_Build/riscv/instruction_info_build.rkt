#lang racket
(require racket/string
         "build_help.rkt")

;; 自定义 index-of（返回 0-indexed 位置，未找到为 #f）
(define (my-index-of lst elem)
  (let loop ([l lst] [i 0])
    (cond
      [(null? l) #f]
      [(equal? (car l) elem) i]
      [else (loop (cdr l) (+ i 1))])))

;; 主函数：构建单个扩展的指令信息文件（字段哈希 + 字段列表）
(define (build-riscv-instruction-info-file in-file out-file type-sym)
  (define all-instructions '())
  (define all-fields '())

  ;; 第一遍：解析所有有效指令行
  (with-input-from-file in-file
    (λ ()
      (for ([line (in-lines)]
            [n (in-naturals 1)])
        (define trimmed (string-trim line))
        (unless (or (string=? trimmed "")
                    (string-prefix? trimmed "#")
                    (string-prefix? trimmed "$"))
          (define inst (extract-mnemonic-and-operands trimmed n))
          (when inst
            (set! all-instructions (cons inst all-instructions))
            ;; 收集所有字段名（去重，保持首次出现顺序）
            (for-each (λ (field)
                        (unless (member field all-fields)
                          (set! all-fields (cons field all-fields))))
                      (cdr inst)))))))

  ;; 恢复原始顺序
  (set! all-instructions (reverse all-instructions))
  (set! all-fields (reverse all-fields))

  ;; 写出 Racket 文件
  (with-output-to-file out-file #:exists 'replace
    (λ ()
      (displayln "#lang racket")
      (newline)

      ;; 1. 字段哈希表
      (for-each
        (λ (field)
          (define bindings '())
          (for-each
            (λ (inst)
              (match-let ([(cons mnemonic ops) inst])
                (define pos0 (my-index-of ops field))
                (when pos0
                  (set! bindings
                        (cons (format "(~a . ~a)" mnemonic (+ pos0 1))
                              bindings)))))
            all-instructions)
          (define var-name (format "~a-~a" type-sym field))
          (if (null? bindings)
              (printf "(define ~a (make-immutable-hash '()))\n" var-name)
              (begin
                (printf "(define ~a\n" var-name)
                (printf "  (make-immutable-hash\n")
                (printf "    '(\n")
                (for-each (λ (b) (printf "      ~a\n" b)) (reverse bindings))
                (printf "    )))\n"))))
        all-fields)

      (newline)

      ;; 2. 字段列表
      (define fields-var (format "~a-fields" type-sym))
      (if (null? all-fields)
          (printf "(define ~a '())\n" fields-var)
          (begin
            (printf "(define ~a '(" fields-var)
            (for-each (λ (f) (printf "~a " f)) all-fields)
            (printf "))\n")))

      (newline)

      ;; 3. Provide
      (displayln "(provide")
      (for-each (λ (field)
                  (printf "  ~a-~a\n" type-sym field))
                all-fields)
      (printf "  ~a)\n" fields-var))))

;; 构建全局指令 → 扩展列表映射（允许多个扩展）
(define (build-global-instruction-extension-map files output-path)
  (define mapping (make-hash)) ; mutable hash: mnemonic -> list of type-sym

  (for ([file-info (in-list files)])
    (match-let ([(cons in-file type-sym) file-info])
      (with-input-from-file in-file
        (λ ()
          (for ([line (in-lines)]
                [n (in-naturals 1)])
            (define trimmed (string-trim line))
            (unless (or (string=? trimmed "")
                        (string-prefix? trimmed "#")
                        (string-prefix? trimmed "$"))
              (define inst (extract-mnemonic-and-operands trimmed n))
              (when inst
                (define mnemonic (car inst))
                ;; 累积到列表（保持顺序：先出现的在前）
                (hash-update! mapping mnemonic
                              (λ (lst) (cons type-sym lst))
                              '()))))))))

  ;; 写出 Racket 文件
  (with-output-to-file output-path #:exists 'replace
    (λ ()
      (displayln "#lang racket")
      (newline)
      (displayln "(define instruction->extensions")
      (displayln "  (make-immutable-hash")
      (displayln "    '(")
      ;; 注意：hash 的遍历顺序不确定，但我们希望输出稳定 → 排序
      (define sorted-items
        (sort (hash->list mapping)
              string<? #:key (λ (p) (symbol->string (car p)))))
      (for-each (λ (pair)
                  (define mnemonic (car pair))
                  (define exts (reverse (cdr pair))) ; 恢复文件处理顺序（最早在前）
                  (printf "      (~a . (~a))\n"
                          mnemonic
                          (string-join (map symbol->string exts) " ")))
                sorted-items)
      (displayln "    )))")
      (newline)
      (displayln "(provide instruction->extensions)")))
      (build-instruction-info-helper-functions output-path)
      )

;; 追加写入辅助查询函数到 instruction_info.rkt
;; output-path: e.g., "riscv/instruction_info/instruction_info.rkt"
(define (build-instruction-info-helper-functions output-path)
  (with-output-to-file output-path #:exists 'append
    (λ ()
      (newline)
      (displayln ";; ====== Auto-generated helper functions ======")
      (newline)

      ;; get-extensions
      (displayln "(define (get-extensions mnemonic)")
      (displayln "  (hash-ref instruction->extensions mnemonic '()))")
      (newline)

      ;; get-primary-extension
      (displayln "(define (get-primary-extension mnemonic)")
      (displayln "  (define exts (get-extensions mnemonic))")
      (displayln "  (if (null? exts) #f (car exts)))")
      (newline)

      ;; instruction-in-extension?
      (displayln "(define (instruction-in-extension? mnemonic ext-sym)")
      (displayln "  (member ext-sym (get-extensions mnemonic)))")
      (newline)

      ;; 额外 provide（Racket 允许多个 provide 表达式）
      (displayln "(provide get-extensions")
      (displayln "         get-primary-extension")
      (displayln "         instruction-in-extension?)"))))

;; 构建指令数量统计文件
;; files: list of (cons input-file type-sym)
;; output-path: e.g., "riscv/instruction_info/instruction_counts.rkt"
(define (build-instruction-counts files output-path)
  (define per-extension '()) ; list of (cons type-sym count)
  (define all-mnemonics (mutable-set))

  ;; 遍历每个文件，统计
  (for ([file-info (in-list files)])
    (match-let ([(cons in-file type-sym) file-info])
      (define count 0)
      (with-input-from-file in-file
        (λ ()
          (for ([line (in-lines)]
                [n (in-naturals 1)])
            (define trimmed (string-trim line))
            (unless (or (string=? trimmed "")
                        (string-prefix? trimmed "#")
                        (string-prefix? trimmed "$"))
              (define inst (extract-mnemonic-and-operands trimmed n))
              (when inst
                (set! count (+ count 1))
                (set-add! all-mnemonics (car inst)))))))
      (set! per-extension (cons (cons type-sym count) per-extension))))

  (define total-unique (set-count all-mnemonics))
  (define total-with-dup (apply + (map cdr per-extension)))

  ;; 写出 Racket 统计文件
  (with-output-to-file output-path #:exists 'replace
    (λ ()
      (displayln "#lang racket")
      (newline)
      (printf "(define total-unique-instructions ~a)\n" total-unique)
      (printf "(define total-instructions-with-duplicates ~a)\n" total-with-dup)
      (newline)
      (displayln "(define per-extension-instruction-count")
      (displayln "  (make-immutable-hash")
      (displayln "    '(")
      (for-each (λ (pair)
                  (printf "      (~a . ~a)\n" (car pair) (cdr pair)))
                (reverse per-extension))
      (displayln "    )))")
      (newline)
      (displayln "(provide total-unique-instructions")
      (displayln "         total-instructions-with-duplicates")
      (displayln "         per-extension-instruction-count)")))
      ;; 第二步：追加辅助函数
      (build-instruction-counts-helper-functions output-path)

  ;; 返回统计值供打印（可选）
  (values total-unique total-with-dup (reverse per-extension)))

;; 追加辅助函数到 instruction_counts.rkt
(define (build-instruction-counts-helper-functions output-path)
  (with-output-to-file output-path #:exists 'append
    (λ ()
      (newline)
      (displayln ";; ====== Auto-generated stats helper functions ======")
      (newline)

      ;; 获取某扩展的指令数量
      (displayln "(define (get-extension-instruction-count ext-sym)")
      (displayln "  (hash-ref per-extension-instruction-count ext-sym #f))")
      (newline)

      ;; 列出所有扩展名（按字母序）
      (displayln "(define (list-all-extensions)")
      (displayln "  (sort (hash-keys per-extension-instruction-count) symbol<?))")
      (newline)

      ;; 检查是否是已知扩展
      (displayln "(define (valid-extension? ext-sym)")
      (displayln "  (hash-has-key? per-extension-instruction-count ext-sym))")
      (newline)

      ;; 提供新函数
      (displayln "(provide get-extension-instruction-count")
      (displayln "         list-all-extensions")
      (displayln "         valid-extension?)"))))

;; 导出所有函数
(provide build-riscv-instruction-info-file
         build-global-instruction-extension-map
         build-instruction-counts)