#lang racket
;;; amd64/loko-compatibility/sexp-read-test.rkt
;;;
;;; sexp-read.rkt 的判据只有一条硬要求：**和 `read` 读出来一模一样**。
;;; 快是目的，但"读得不一样"就是错。这里用两种方式验：
;;;   1. 一小段覆盖各种写法的语料：逐 item `equal?`
;;;   2. 大 dump（如果环境里有）：逐 item `equal?`（LS_EXPECT_DUMP=/tmp/pc.sexp）
;;; 另外验 2 件 `equal?` 抓不到的事：符号是 intern 的（`eq?`），坏输入会报错。

(require rackunit
         racket/port
         "sexp-read.rkt")

(define corpus
  (string-append
   ;; 普通 item
   "(mov rax (mem64+ rsp 8))\n"
   "(%label image-address-zero)\n"
   "(%u64 18446744073709551615 0 -1 4611686018427387904)\n"
   "(%u32 -0x10)\n"
   ;; 符号的各种拼写
   "(+ - * / %u64 mem64+ *branched* a.b:c 1+ ... ->x)\n"
   "(|weird symbol with spaces| |0.0| |a\\\\b|)\n"
   ;; 数字里容易读错的东西
   "(0.0 -0.0 .000000000000000000009999999682655225 1/3 1e10 -1. 0+1i +inf.0)\n"
   ;; 字符串 / 字符 / bytevector
   "(str \"\" \"plain\" \"quote\\\" back\\\\ \" \"u\\u41\" \"ctl\\n\")\n"
   "(ch #\\a #\\space #\\uD7A3 #\\x41)\n"
   "(bv #\"\" #\"\\x00\\xff\\x10\" #\"\\x41\\x42\")\n"
   ;; vector / Loko printer 那种 #[...] / 点对 / #t #f
   "(vec #(1 2 (3 . 4)) #[] #[const value: #(\"f\" 1 0) ref: #f])\n"
   "(dotted (a . b) (a b . c))\n"
   "(bools #t #f #true #false)\n"
   ;; 注释、空行、行尾空白
   ";; a comment line\n"
   "\n"
   "(spaced   (  a   b  )   )   \n"
   "(last item)\n"))

(define (read-all text)
  (call-with-input-string text
    (lambda (in) (for/list ([x (in-port read in)]) x))))

(define (fast-all text)
  (read-dump-bytes (string->bytes/utf-8 text)))

(define got (fast-all corpus))

(check-equal? got (read-all corpus) "语料：逐 item 和 `read` 相同")

;; 逐条也要能定位问题（整份 equal? 只说"不同"）
(for ([a (in-list got)] [b (in-list (read-all corpus))] [i (in-naturals)])
  (check-equal? a b (format "第 ~a 个 item" i)))

;; 符号必须 intern：翻译层大量用 `eq?` 比指令名/寄存器名
(define sym-items (fast-all "(mov rax 1)\n(mov rbx 2)\n"))
(check-true (eq? (car (car sym-items)) (car (cadr sym-items))))

;; 坏输入要报错，不能"读出一个看起来像样的东西"
(check-exn exn:fail? (lambda () (fast-all "(unterminated\n")))
(check-exn exn:fail? (lambda () (fast-all "(a ]\n")))

;; 真实 dump（可选）：LS_EXPECT_DUMP 指到 Loko sexp target 的产物
(define dump-path (getenv "LS_EXPECT_DUMP"))
(when (and dump-path (file-exists? dump-path))
  (define fast (read-dump dump-path))
  (define slow (with-input-from-file dump-path
                 (lambda () (for/list ([x (in-port read)]) x))))
  (check-equal? (length fast) (length slow) "dump：item 数")
  (define bad
    (for/first ([a (in-list fast)] [b (in-list slow)] #:unless (equal? a b)) (list a b)))
  (check-false bad (if bad
                       (format "dump：第一处不同\n  fast: ~e\n  read: ~e"
                               (car bad) (cadr bad))
                       "")))

(printf "sexp-read: ~a corpus items ok~a\n"
        (length got)
        (if dump-path (format "，dump ~a" dump-path) ""))
