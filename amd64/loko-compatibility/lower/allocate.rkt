#lang racket
;;; amd64/loko-compatibility/lower/allocate.rkt
;;;
;;; 伪寄存器 -> 物理寄存器的图着色分配。
;;;
;;; 输入是 liveness.rkt 的结果；输出：
;;;
;;;   (allocation-result
;;;     (hash 伪下标 物理寄存器 ...)
;;;     (未着色伪下标 ...)
;;;     (可用物理寄存器 ...))
;;;
;;; 这是“能跑起来”的第一版，不是完整的 Loko 分配器：
;;;   - 做干涉图着色，允许不重叠的伪寄存器复用同一个物理寄存器；
;;;   - 不做 coalescing；
;;;   - 不做 spill；
;;;   - 不模拟调用约定。
;;;
;;; 最后一点很重要：Loko 只在调用点保存/恢复 live 的伪寄存器。
;;; 如果一段代码跨调用还 live，分配器把伪寄存器放进 caller-saved 寄存器
;;; 后，调用会破坏它。当前版本把这件事留给后续的 spill/call-save 层；
;;; 需要保守时，调用方应只传 preserved-registers 作为 available。
;;;
;;; 图着色本身是纯函数：节点顺序固定，颜色顺序由 available 列表决定，
;;; 同样的 liveness + available 得到同样的分配。

(require "../../compiler/analyze/analyze.rkt"
         "uses.rkt"
         "liveness.rkt")

(provide (struct-out allocation-result)
         allocate-pseudo-registers
         allocation-result->alist
         default-available-registers
         preserved-registers)

;; Loko 可用的 GPR：scratch + preserved，去掉 %pcb/%closure/rsp。
;; 这是默认集合，不代表跨调用安全。
(define default-available-registers
  '(rax rcx rdx rsi rdi r8 r9 r10 r11 r12 r13 rbx rbp))

;; Loko target-convention 里真正跨调用保留的寄存器。
(define preserved-registers '(rbx rbp))

(struct allocation-result (allocation uncolored available) #:transparent)

(define (allocation-result->alist result)
  (sort (hash->list (allocation-result-allocation result))
        < #:key car))

;; ---------------------------------------------------------------------------
;; 干涉图
;; ---------------------------------------------------------------------------

(define (make-graph)
  (make-hash))

(define (neighbors g n)
  (hash-ref g n (hash)))

(define (edge! g a b)
  (unless (= a b)
    (hash-set! g a (hash-set (neighbors g a) b #t))
    (hash-set! g b (hash-set (neighbors g b) a #t))))

(define (clique! g nodes)
  (for* ([a (in-list nodes)]
         [b (in-list nodes)])
    (edge! g a b)))

;; ---------------------------------------------------------------------------
;; 着色
;; ---------------------------------------------------------------------------

(define (degree g n) (hash-count (neighbors g n)))

(define (color-graph g nodes available)
  ;; 高度节点先着色；度数相同时按下标，保证确定性。
  (define ordered
    (sort nodes (lambda (a b)
                  (define da (degree g a))
                  (define db (degree g b))
                  (if (= da db) (< a b) (> da db)))))
  (define colors (make-hash))
  (define uncolored '())
  (for ([n (in-list ordered)])
    (define used
      (for/hash ([nb (in-hash-keys (neighbors g n))]
                 #:when (hash-ref colors nb #f))
        (values (hash-ref colors nb) #t)))
    (define color
      (for/or ([r (in-list available)])
        (and (not (hash-ref used r #f)) r)))
    (if color
        (hash-set! colors n color)
        (set! uncolored (cons n uncolored))))
  (values colors (sort uncolored <)))

;; ---------------------------------------------------------------------------
;; 入口
;; ---------------------------------------------------------------------------

;; liveness 只存集合；干涉图还需要知道每条指令的 defs，所以这里同时
;; 接受 program（或 item 列表）：
;;
;;   (allocate-pseudo-registers lv program #:available ...)
(define (allocate-pseudo-registers lv program-or-items
                                   #:available [available default-available-registers])
  (define prog (if (program? program-or-items)
                   program-or-items
                   (analyze program-or-items)))
  (define blocks (list->vector (program-blocks prog)))
  (define g (make-graph))

  ;; 块入口 clique
  (for ([i (in-range (vector-length blocks))])
    (clique! g (vector-ref (liveness-live-ins lv) i)))

  ;; 每条指令：defs vs live-out，defs 内部互相干涉。
  (for ([i (in-range (vector-length blocks))])
    (define items (block-items (vector-ref blocks i)))
    (for ([j (in-range (length items))])
      (define item (list-ref items j))
      (define live-out (live-out-after lv i j))
      (define-values (_uses defs) (instruction-uses/sets item))
      (for ([d (in-list defs)])
        (for ([l (in-list live-out)])
          (edge! g d l)))
      (clique! g defs)))

  (define-values (colors uncolored)
    (color-graph g (liveness-pseudos lv) available))
  (allocation-result colors uncolored available))
