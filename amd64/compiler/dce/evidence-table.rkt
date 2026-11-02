#lang racket
;;; amd64/compiler/dce/evidence-table.rkt
;;;
;;; DCE 删除不可达块时，愿意接受的“不落下”依据。
;;;
;;; 这是政策表，不是 amd64-asm 的 flow 事实：
;;;   - amd64-asm 回答“这条 form 会不会顺序落下”；
;;;   - 本表回答“删代码时，哪些不落下依据我敢信”。
;;;
;;; 新增 stop form 时，必须同时改这里和 amd64-asm/special/table.rkt。

(require "../../amd64-asm/shape.rkt")

(provide accepted-stop-forms
         accepted-deletion-evidence?)

;; 只有硬件明确保证不继续、且我们愿意据此删除后续代码的 stop form。
(define accepted-stop-forms '(ret ud2))

(define (accepted-deletion-evidence? reason last-item)
  (case reason
    [(jump jump-indirect) #t]
    [(stop) (and (form? last-item)
                 (memq (car last-item) accepted-stop-forms))]
    [else #f]))
