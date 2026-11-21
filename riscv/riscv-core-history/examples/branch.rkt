#lang racket
;;; 条件分支 + 一条 jump。
;;; b0 --eq--> b2
;;; b0 --else--> b1 --jump--> b2

(provide branch-virtual
         branch-allocation
         branch-machine)

(define branch-virtual
  '(func (main)
     (vregs
       (($ a) (b8))
       (($ b) (b8))
       (($ t) (b64)))
     (entry b0)

     (block b0
       (add ($ t) ($ a) ($ b))
       (term (branch (eq ($ t) 0) b2 b1)))

     (block b1
       (add ($ t) ($ t) 1)
       (term (jump b2)))

     (block b2
       (term (return ($ t))))))

(define branch-allocation
  '(allocation
     (($ a) (native x10))
     (($ b) (native x11))
     (($ t) (native x12))))

(define branch-machine
  '(func (main)
     (entry b0)

     (block b0
       (add (native x12) (native x10) (native x11))
       (term (branch (eq (native x12) 0) b2 b1)))

     (block b1
       (add (native x12) (native x12) 1)
       (term (jump b2)))

     (block b2
       (term (return (native x12))))))
