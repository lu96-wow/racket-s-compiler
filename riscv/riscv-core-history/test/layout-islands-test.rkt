#lang racket
;;; test/layout-islands-test.rkt
;;;
;;; islands：far branch / far jump；不拆块；无可达 slot 直接报错。

(require rackunit
         racket/list
         "../layout/relax.rkt"
         "../layout/plan.rkt"
         "../layout/policy.rkt")

(define frame16
  '(frame
     (size 16)
     (header 16)
     (outgoing 0)
     (align 16)
     (slots)))

(define (machine-func blocks)
  (append (list 'func '(main) frame16 '(scratch) '(entry b0))
          blocks))

(define (make-plan order fallthrough)
  (layout-plan '(main) 'b0 order
               (for/hash ([pair (in-list fallthrough)])
                 (values (car pair) (cadr pair)))))

(define islands-policy
  (make-layout-policy #:far-branch 'islands #:far-jump 'islands))

(define (items-of func plan)
  (layout-result-items
   (layout-func func plan #:policy islands-policy)))

;; ---------------------------------------------------------------------------
;; far branch
;; ---------------------------------------------------------------------------

(test-case "far branch uses an island at a reachable boundary"
  (define big-body
    (for/list ([i (in-range 1100)])
      '(addi (native x5) (native x5) 1)))
  (define func
    (machine-func
     (list '(block b0
              (term (branch (eq (native x12) 0) b2 b1)))
           '(block b1
              (term (return)))
           (list* 'block 'b3
                  (append big-body (list '(term (return)))))
           '(block b2
              (term (return))))))
  (define plan (make-plan '(b0 b1 b3 b2) '((b0 b1))))
  (define result (layout-func func plan #:policy islands-policy))
  (define items (layout-result-items result))

  (check-equal? (layout-result-scratch-request result) 0)
  (check-equal? (take items 6)
                '((label b0)
                  (beq island-0 (native x12) (native x0))
                  (label b1)
                  (jalr (native x0) (native x1) 0)
                  (label island-0)
                  (jal (native x0) b2)))
  ;; fallthrough b0 -> b1 没有被 island 打断。
  (check-equal? (list-ref items 2) '(label b1))
  (check-true (and (member '(label b2) items) #t)))

(test-case "far branch without a reachable slot is an error"
  (define big-body
    (for/list ([i (in-range 1100)])
      '(addi (native x5) (native x5) 1)))
  (define func
    (machine-func
     (list '(block b0
              (term (branch (eq (native x12) 0) b2 b1)))
           (list* 'block 'b1
                  (append big-body (list '(term (return)))))
           '(block b2
              (term (return))))))
  (define plan (make-plan '(b0 b1 b2) '((b0 b1))))
  (check-exn #rx"no reachable slot"
             (lambda ()
               (layout-func func plan #:policy islands-policy))))

;; ---------------------------------------------------------------------------
;; far jump
;; ---------------------------------------------------------------------------

(test-case "far jump uses an island roughly in the middle"
  (define half-body
    (for/list ([i (in-range 140000)])
      '(addi (native x5) (native x5) 1)))
  (define func
    (machine-func
     (list '(block b0
              (term (jump b3)))
           (list* 'block 'b1
                  (append half-body (list '(term (return)))))
           (list* 'block 'b2
                  (append half-body (list '(term (return)))))
           '(block b3
              (term (return))))))
  (define plan (make-plan '(b0 b1 b2 b3) '()))
  (define result (layout-func func plan #:policy islands-policy))
  (define items (layout-result-items result))

  (check-equal? (layout-result-scratch-request result) 0)
  (check-equal? (take items 4)
                '((label b0)
                  (jal (native x0) island-0)
                  (label b1)
                  (addi (native x5) (native x5) 1)))
  (check-true (and (member '(label island-0) items) #t))
  (check-true (and (member '(jal (native x0) b3) items) #t)))

;; ---------------------------------------------------------------------------
;; policy
;; ---------------------------------------------------------------------------

(test-case "mixed island/inline policy is rejected"
  (define func
    (machine-func
     '((block b0 (term (return))))))
  (define plan (make-plan '(b0) '()))
  (check-exn #rx"mixed island/inline policy"
             (lambda ()
               (layout-func func plan
                            #:policy (make-layout-policy
                                      #:far-branch 'islands
                                      #:far-jump 'inline)))))
