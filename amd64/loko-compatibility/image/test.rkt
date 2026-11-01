#lang racket
;;; amd64/loko-compatibility/image/test.rkt

(require rackunit
         "../translate.rkt"
         "layout-spec.rkt"
         "plan.rkt")

(define (loko-ir-of src)
  (define fields (cdr (translate-loko-source src)))
  (list 'loko-ir
        (assq 'origin fields)
        (assq 'symbols fields)
        (assq 'comms fields)
        (assq 'sections fields)))

(define-values (spec program-items data-items problems)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text
       (%origin #x200000)
       (%mode 64)
       (%section text)
       (%label text)
       (ret))
      (data
       (%label bss)
       (%section bss)
       (reserve 32)
       (%label bss-end))))))

(check-equal? problems '())
;; 段声明只有约束(size / align), 没有地址: 起点由 compiler/layout 求解
(check-equal? spec
              '((origin #x200000)
                (segments
                 (segment (name text) (kind code) (size 1) (align 1))
                 (segment (name data) (kind data) (size 0) (align 1))
                 (segment (name bss) (kind hole) (size 32) (align 1)))
                (place text (text))
                (place data (bss))
                (place bss (loko-image-start-bss) (bss-end))))

;; 计划里的对齐约束会进到 (align …): 页边界就是这么流进地址分配的
(define-values (plan-spec _pi _di _pr)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text (%origin #x200000) (%mode 64) (%section text) (%label text) (ret))
      (data (%label bss) (%section bss) (reserve 32) (%label bss-end))))
   (loko-linux-image-plan)))
(check-equal? (assq 'origin plan-spec) '(origin #x200000))
(check-equal? (cdr (assq 'segments plan-spec))
              '((segment (name text) (kind code) (size 1) (align 4096))
                (segment (name data) (kind data) (size 0) (align 4096))
                (segment (name bss) (kind hole) (size 32) (align 4096))))
(check-equal? program-items '((label text) (ret)))
(check-equal? data-items
              '((label bss)
                (comment section-boundary bss)
                (label loko-image-start-bss)
                (reserve 32)
                (label bss-end)))

;; 32 位代码不再一律报错: 只有"用 64 位路径编码不等价"的 item 才报
;; (判据见 loko-compatibility/mode32.rkt; 那 101 个引导 item 全部通过)
(define-values (_spec2 _p2 _d2 problems2)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text (%origin 0) (%mode 32) (%section text) (%label text)
            (mov eax 16) (mov ds ax) (ret))
      (data)))))
(check-equal? problems2 '())

;; 32 位段里出现模式敏感指令 -> 报出具体的 item, 而不是默默按 64 位编码
(define-values (_spec3 _p3 _d3 problems3)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text (%origin 0) (%mode 32) (%section text) (%label text) (mov rax 5) (ret))
      (data)))))
(check-true
 (for/or ([p (in-list problems3)])
   (and (eq? (cadr p) 'mode32-unsupported-form)
        (equal? (caddr p) 'text)
        (equal? (cadddr p) '(mov rax 5)))))

;; 16 位模式仍然不支持
(define-values (_spec4 _p4 _d4 problems4)
  (build-layout-spec
   (loko-ir-of
    '(loko-source
      (text (%origin 0) (%mode 16) (%section text) (%label text) (ret))
      (data)))))
(check-true
 (for/or ([p (in-list problems4)])
   (equal? p '(problem mode-unsupported text 16))))

;; Loko Linux plan: plan-only stack/heap regions, no host callbacks.
(check-equal? (choose-loko-linux-image-plan '() '()) '())
(check-equal? (choose-loko-linux-image-plan
               '((symbol (elf-entry) text 0 #x200000))
               '())
              (loko-linux-image-plan))
(check-equal? (choose-loko-linux-image-plan
               '((symbol (elf-entry) text 0 #x200000))
               '((entry (text))))
              '((entry (text))))
(check-equal? loko-linux-stack-start (expt 2 40))
(check-equal? loko-linux-heap-start (+ (expt 2 40) (* 2 1024 1024)))
(define plan (loko-linux-image-plan))
(check-true (for/or ([c (in-list plan)])
              (and (eq? (car c) 'region)
                   (eq? (cadr (assq 'id (cdr c))) 'stack0)
                   (eq? (cadr (assq 'content (cdr c))) 'reserved))))
(check-true (for/or ([c (in-list plan)])
              (and (eq? (car c) 'region)
                   (eq? (cadr (assq 'id (cdr c))) 'heap0))))

(displayln "amd64 loko-image tests: ok")
