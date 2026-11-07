#lang racket
;;; link-file-test.rkt -- build -> 单独一个 link 文件
;;;
;;; 锁住：
;;;   - link 文件 = link 表按 provides 过滤（link 表本身仍是全量）
;;;   - 内容形状 = 输入侧同一份 (link (base B) (symbol 链 地址) …)
;;;   - 没有 provide 子句时是全导出
;;;   - 写出去的文件 read 得回来，且能直接当下一份的输入

(require rackunit
         racket/list
         "helpers.rkt"
         (only-in "../riscv-compiler/flow/flow.rkt"
                  run-flow flow-value default-flow)
         (only-in "../riscv-compiler/target.rkt" target-rv64-base)
         (only-in "../riscv-compiler/link-file.rkt"
                  link-file link-file->string write-link-file))

(define target target-rv64-base)

(define (build-of src spec)
  (flow-value
   (run-flow target default-flow
             (list (cons 'rich-data '())
                   (cons 'program-items src)
                   (cons 'layout-spec spec)))
   'build))

(define spec
  '((origin #x1000)
    (segments (segment (name c) (kind code) (start #x1000) (end #x2000) (align 4)))
    (place c (main))))

;; ---------------------------------------------------------------------------
;; 没有 provide 子句: 全导出(平铺镜像语义)
;; ---------------------------------------------------------------------------

(define bare (build-of '((label main) (jalr x0 ra 0)) spec))

(check-equal? (build-provides bare) '(provides (main)))
(check-equal? (link-file bare) '(link (base #x1000) (symbol (main) #x1000)))

;; ---------------------------------------------------------------------------
;; 有 provide: link 表是全量, provides 只列对外承诺的
;; ---------------------------------------------------------------------------

(define mod-src
  '((module m
       (provide f)
       (label f) (beq (g) a0 a1)
       (label g) (jalr x0 ra 0))))

(define mod-spec
  '((origin #x1000)
    (segments (segment (name c) (kind code) (start #x1000) (end #x2000) (align 4)))
    (place c (m f) (m g))))

(define mod (build-of mod-src mod-spec))

;; link 表里有 f 也有 g（g 可达, 只是不导出）
(check-equal? (map cadr (cddr (findf (lambda (x) (eq? (car x) 'link)) (cdr mod))))
              '((m f) (m g)))
(check-equal? (build-provides mod) '(provides (m f)))

;; link 文件只留 f
(check-equal? (link-file mod) '(link (base #x1000) (symbol (m f) #x1000)))

;; ---------------------------------------------------------------------------
;; 写文件: read 得回来, 形状和输入侧一致
;; ---------------------------------------------------------------------------

(define out (build-path (find-system-path 'temp-dir) "riscv-link-file-test.link"))
(dynamic-wind
  void
  (lambda ()
    (write-link-file mod out)
    (check-equal? (with-input-from-file out read) (link-file mod))
    (check-equal? (file->string out) (link-file->string mod))
    ;; 形状可直接当输入: 第一项是 link, 第二项是 (base …)
    (define datum (with-input-from-file out read))
    (check-equal? (car datum) 'link)
    (check-equal? (car (cadr datum)) 'base))
  (lambda () (when (file-exists? out) (delete-file out))))

;; ---------------------------------------------------------------------------
;; 入口检查
;; ---------------------------------------------------------------------------

(check-error "缺 link" (lambda () (link-file '(build (provides)))))
(check-error "缺 provides" (lambda () (link-file '(build (link (base 0))))))

(displayln "link-file tests: ok")
