#lang racket
;;; amd64/compiler/layout/test.rkt

(require rackunit
         "../../amd64-asm/target.rkt"
         "../analyze/analyze.rkt"
         "layout.rkt"
         "forms.rkt")

(check-equal? (item-size '(value 8 1)) 8)
(check-equal? (item-size '(pad 5)) 5)
(check-equal? (item-size '(reserve 32)) 32)
(check-equal? (item-size '(comment liveness)) 0)
(check-equal? (item-size '(align 16)) #f)
(check-equal? (item-size '(mov rax rbx)) 3)
(check-equal? (item-size '(jmp-near (done))) 5)
(check-equal? (align-pad #x200003 8) 5)
(check-equal? (align-pad #x200000 16) 0)

(define spec
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x200100) (align 16))
     (segment (name data) (kind data) (start #x300000) (end #x300100) (align 8)))
    (place text (text))
    (place data (data))))

(define out
  (layout-flat-items
   target-amd64
   '((label text)
     (align 4)
     (mov rax rbx)
     (jmp-near (done))
     (label done)
     (ret)
     (label data)
     (value 8 #x1234))
   spec))

(check-equal? (cdr (assq 'problems out)) '())
(check-equal? (cdr (assq 'anchors out))
              '((anchor (text) text 0)
                (anchor (done) text 8)
                (anchor (data) data 0)))

(define text
  (car (cdr (assq 'segments out))))
(define text-fields (cdr text))
(define items (cdr (assq 'items text-fields)))
(check-equal? (map car items) '(offset offset offset offset))
(check-equal? (map cadr items) '(0 0 3 8))
(check-equal? (cadr (assq 'size text-fields)) 9)

;; --- hole 段: 有位置, 没有文件字节 ---------------------------------------
;;
;; 归一化只有一个分叉: align 在 hole 段里变 reserve, 在 code/data 段里变 pad。
;; 所以 hole 段的 items 永远只含 label / comment / reserve。

(define (hole-spec)
  '((segments
     (segment (name text) (kind code) (start #x200000) (end #x200100) (align 16))
     (segment (name bss) (kind hole) (start #x300000) (end #x301000) (align 16)))
    (place text (text))
    (place bss (bss) (common))))

(define hole-items
  '((label text) (ret)
    (label bss) (reserve 3) (align 16)
    (label common) (reserve 32)))

(define hole-out (layout-flat-items target-amd64 hole-items (hole-spec)))

(check-equal? (cdr (assq 'problems hole-out)) '())
(check-equal? (cdr (assq 'anchors hole-out))
              '((anchor (text) text 0)
                (anchor (bss) bss 0)
                (anchor (common) bss 16)))

(define hole-seg (cadr (cdr (assq 'segments hole-out))))
(check-equal? (cadr (assq 'size (cdr hole-seg))) 48)

;; align(16) 在 0x300003 处要补 13 字节 —— 进产物是 (reserve 13), 不是 (pad 13)
(define hole-seg-items (cdr (assq 'items (cdr hole-seg))))
(check-equal? (map cadr hole-seg-items) '(0 3 16))
(check-equal? (map caddr hole-seg-items)
              '((reserve 3) (reserve 13) (reserve 32)))

;; 不变量: hole 段里没有任何要写字节的 item (label 在 amd64 只进 anchors)
(check-equal? (map (lambda (it) (car (caddr it))) hole-seg-items)
              '(reserve reserve reserve))

;; hole 段不收要写字节的东西
(define (problem-kinds items spec)
  (map car (cdr (assq 'problems (layout-flat-items target-amd64 items spec)))))

(check-equal? (problem-kinds '((label text) (ret) (label bss) (bytes 1 2)) (hole-spec))
              '(hole-materialized-item))
(check-equal? (problem-kinds '((label text) (ret) (label bss) (pad 4)) (hole-spec))
              '(hole-materialized-item))
(check-equal? (problem-kinds '((label text) (ret) (label bss) (mov rax rbx)) (hole-spec))
              '(hole-materialized-item))

;; reserve 只属于 hole 段
(check-equal? (problem-kinds '((label text) (ret) (label data) (reserve 8))
                             '((segments
                                (segment (name text) (kind code) (start #x200000) (end #x200100) (align 16))
                                (segment (name data) (kind data) (start #x300000) (end #x301000) (align 8)))
                               (place text (text))
                               (place data (data))))
              '(reserve-outside-hole))

;; 段 kind 只回答"收哪些 item 类"
(check-true  (item-kind-allowed-in? 'code 'code))
(check-true  (item-kind-allowed-in? 'materialized 'code))  ; code 段可以放数据
(check-false (item-kind-allowed-in? 'space 'code))
(check-true  (item-kind-allowed-in? 'materialized 'data))
(check-false (item-kind-allowed-in? 'code 'data))
(check-false (item-kind-allowed-in? 'space 'data))
(check-true  (item-kind-allowed-in? 'space 'hole))
(check-true  (item-kind-allowed-in? 'align 'hole))
(check-false (item-kind-allowed-in? 'materialized 'hole))
(check-false (item-kind-allowed-in? 'pad 'hole))
(check-false (item-kind-allowed-in? 'code 'hole))

;; item 类别
(check-equal? (item-kind '(label a)) 'marker)
(check-equal? (item-kind '(comment liveness)) 'marker)
(check-equal? (item-kind '(align 16)) 'align)
(check-equal? (item-kind '(pad 4)) 'pad)
(check-equal? (item-kind '(reserve 8)) 'space)
(check-equal? (item-kind '(bytes 1 2)) 'materialized)
(check-equal? (item-kind '(fill 4 0)) 'materialized)
(check-equal? (item-kind '(value 8 1)) 'materialized)
(check-equal? (item-kind '(mov rax rbx)) 'code)

(displayln "amd64 layout tests: ok")


;; ---------------------------------------------------------------------------
;; block-aware placement / validation
;; ---------------------------------------------------------------------------

(define (has-problem? out kind)
  (for/or ([p (in-list (cdr (assq 'problems out)))])
    (eq? (car p) kind)))

(define (code-seg name start end)
  (list 'segment (list 'name name) (list 'kind 'code)
        (list 'start start) (list 'end end) (list 'align 16)))

(define (data-seg name start end)
  (list 'segment (list 'name name) (list 'kind 'data)
        (list 'start start) (list 'end end) (list 'align 8)))

;; fallthrough into another segment is a layout problem
(define ft-prog
  (analyze '((label a) (jcc-near e b) (label b) (ret)) '()))
(define ft-spec
  (list (list 'segments (code-seg 't1 #x200000 #x200100)
              (code-seg 't2 #x201000 #x201100))
        '(place t1 (a))
        '(place t2 (b))))
(define ft-out (layout-program target-amd64 ft-prog '() ft-spec))
(check-true (has-problem? ft-out 'broken-fallthrough))

;; a block before any place is unplaced
(define unplaced-prog (analyze '((label x) (ret)) '()))
(define unplaced-spec
  (list (list 'segments (code-seg 'text #x200000 #x200100))
        '(place text (y))))
(define unplaced-out (layout-program target-amd64 unplaced-prog '() unplaced-spec))
(check-true (has-problem? unplaced-out 'unplaced-block))

;; (place text *) is the explicit wildcard
(define wildcard-spec
  (list (list 'segments (code-seg 'text #x200000 #x200100))
        '(place text *)))
(define wildcard-out (layout-program target-amd64 unplaced-prog '() wildcard-spec))
(check-equal? (cdr (assq 'problems wildcard-out)) '())
(check-equal? (cdr (assq 'anchors wildcard-out))
              '((anchor (x) text 0)))

;; segment start alignment and overlap are checked before measuring
(define misaligned-spec
  (list (list 'segments
              (list 'segment (list 'name 'text) (list 'kind 'code)
                    (list 'start #x200001) (list 'end #x200100) (list 'align 16)))
        '(place text (x))))
(define misaligned-out (layout-program target-amd64 unplaced-prog '() misaligned-spec))
(check-true (has-problem? misaligned-out 'segment-misaligned))

(define overlap-spec
  (list (list 'segments
              (code-seg 'a #x200000 #x201000)
              (code-seg 'b #x200800 #x202000))
        '(place a (x))))
(define overlap-out (layout-program target-amd64 unplaced-prog '() overlap-spec))
(check-true (has-problem? overlap-out 'segment-overlap))

;; data runs need a label and a place
(define empty-prog (analyze '() '()))
(define unlabeled-out
  (layout-program target-amd64 empty-prog '((value 8 1)) spec))
(check-true (has-problem? unlabeled-out 'unlabeled-run))

(define unplaced-data-out
  (layout-program target-amd64 empty-prog
                  '((label nowhere) (value 8 1))
                  (list (list 'segments (code-seg 'text #x200000 #x200100))
                        '(place text (text)))))
(check-true (has-problem? unplaced-data-out 'unplaced-data))

;; RIP-relative and absolute symbolic addresses are range-checked in layout
(define far-data-spec
  (list (list 'segments (code-seg 'text #x200000 #x201000)
              (data-seg 'data #x100000000 #x100001000))
        '(place text (text))
        '(place data (data))))

(define rip-prog
  (analyze '((label text)
             (mov rax (b64 (base rip) (disp (data))))
             (ret))
           '()))
(define rip-out
  (layout-program target-amd64 rip-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true (has-problem? rip-out 'rip-out-of-range))

(define abs-prog
  (analyze '((label text)
             (mov rax (b64 (disp (data))))
             (ret))
           '()))
(define abs-out
  (layout-program target-amd64 abs-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true (has-problem? abs-out 'absolute-out-of-range))

;; near branch overflow becomes a request, not a silent byte truncation
(define far-branch-prog
  (analyze '((label text)
             (jmp-near (data)))
           '()))
(define far-branch-out
  (layout-program target-amd64 far-branch-prog
                  '((label data) (value 8 0))
                  far-data-spec))
(check-true
 (for/or ([r (in-list (cdr (assq 'requests far-branch-out)))])
   (eq? (car r) 'needs-far)))
