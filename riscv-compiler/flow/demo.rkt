#lang racket
;;; flow/demo.rkt -- 构建流
;;;
;;; (list 层名 ...) 就是整条流水线: 写哪个跑哪个, 顺序就是列表顺序。
;;; 每个层声明"需要哪些在途值 / 产生哪些在途值", 驱动按列表跑并检查依赖。

(require "flow.rkt"
         (only-in "../target.rkt" target-rv64-base))

;; ---------------------------------------------------------------------------
;; 小工具（放在前面：模块级直接调用后面的 define 会报 "before its definition"）
;; ---------------------------------------------------------------------------

(define (seg-size build name)
  (define seg (findf (lambda (s) (equal? (cadr (assoc 'name (cdr s))) name)) (cdr build)))
  (cadr (assoc 'size (cdr seg))))

(define (check-out out)
  (define build (flow-value out 'build))
  (displayln "  产物:")
  (for ([seg (in-list (cdr build))])
    (define name (cadr (assoc 'name (cdr seg))))
    (define start (cadr (assoc 'start (cdr seg))))
    (define bs (cadr (assoc 'bytes (cdr seg))))
    (printf "    ~a start=#x~x size=~a  " name start (bytes-length bs))
    (for ([b (in-bytes bs)]) (printf "~a " (string-upcase (number->string b 16))))
    (newline)))


;; ---------------------------------------------------------------------------
;; 1. 有哪些层
;; ---------------------------------------------------------------------------

(displayln ";; 层（名字是契约，和目录结构无关）")
(for ([n (in-list (stage-names))])
  (define st (hash-ref stage-table n))
  (displayln (format "  ~a  ~a -> ~a" n (stage-requires st) (stage-provides st)))
  (displayln (format "     ~a" (stage-doc st))))
(newline)

;; ---------------------------------------------------------------------------
;; 1.5 层组 / 选择器
;; ---------------------------------------------------------------------------

(displayln ";; 层组（常用片段; 组名不能和层名重名）")
(for ([g (in-list (group-names))])
  (displayln (format "  ~a -> ~a" g (hash-ref stage-groups g))))
(displayln (format "  '(frontend ir backend) -> ~a"
                   (select-stages '(frontend ir backend))))
(newline)

;; ---------------------------------------------------------------------------
;; 2. 一份输入
;; ---------------------------------------------------------------------------

(define src
  '((label main)
    (move a0 a1)                     ; 伪指令: expand-pseudo 展开
    (ble a0 a1 (hot))                ; 伪指令
    (jal x0 (end))
    (label dead) (add a2 a2 a2) (jalr x0 ra 0)   ; 不可达: dce 会删掉
    (label hot) (addi a0 a0 1) (jalr x0 ra 0)
    (label end) (ld t0 sp 8)))

(define rich
  '((label g tab)
    (b64 (main))          ; 数据里的地址字
    (utf-stringz "hi")))

(define layout-spec
  '((segments (segment (name c) (kind code) (start #x100000) (end #x100FFF) (align 16))
              (segment (name d) (kind data) (start #x200000) (end #x200FFF) (align 8)))
    (place c (main) (hot) (end))
    (place d (g tab))))

(define seeds
  (list (cons 'rich-data rich)
        (cons 'program-items src)
        (cons 'layout-spec layout-spec)))

;; ---------------------------------------------------------------------------
;; 3. 默认流
;; ---------------------------------------------------------------------------

(displayln (format ";; 默认流: ~a" default-flow))
(define out (run-flow target-rv64-base default-flow seeds))
(check-out out)

;; ---------------------------------------------------------------------------
;; 4. 换流: 关掉 dce
;; ---------------------------------------------------------------------------

(displayln "\n;; 同一个程序, 去掉 dce")
(define without-dce (remq 'dce default-flow))
(displayln (format "  ~a" without-dce))
(define out2 (run-flow target-rv64-base without-dce seeds))
(displayln (format "  代码段 ~a 字节 (默认流 ~a 字节)"
                   (seg-size (flow-value out2 'build) 'c)
                   (seg-size (flow-value out 'build) 'c)))

;; ---------------------------------------------------------------------------
;; 5. 依赖检查: 少一层就会说清缺什么
;; ---------------------------------------------------------------------------

(displayln "\n;; 忘了 layout/relax/bind-labels, 直接 encode")
(with-handlers ([exn:fail? (lambda (e) (displayln (format "  ~a" (exn-message e))))])
  (run-flow target-rv64-base (list 'expand-data 'flatten 'analyze 'encode) seeds))

(displayln "\n;; 层名写错")
(with-handlers ([exn:fail? (lambda (e) (displayln (format "  ~a" (exn-message e))))])
  (run-flow target-rv64-base (list 'expand-data 'no-such-layer) seeds))

;; ---------------------------------------------------------------------------

