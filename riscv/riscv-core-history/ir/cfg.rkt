#lang racket
;;; ir/cfg.rkt
;;;
;;; 第二步：只从 block + term 抽 CFG。
;;;
;;; 输入是 verify-virtual 通过的 func；这里不重新验证 op / vreg。
;;; 它只关心：
;;;   - entry；
;;;   - block 的文本顺序；
;;;   - 每个 term 的后继；
;;;   - 前驱表；
;;;   - 可达 / 不可达 block。
;;;
;;; 它不改 CFG，也不删 block。DCE / 空 block 合并是后面的 pass。

(require racket/list
         "../core/sexp.rkt")

(provide (struct-out cfg)
         build-cfg
         build-program-cfg
         term-successors
         reachable-blocks
         unreachable-blocks
         cfg-all-reachable?)

;; blocks : 文本顺序的 block 名
;; successors : block 名 -> 后继 block 名列表
;; predecessors : block 名 -> 前驱 block 名列表
(struct cfg (name entry blocks successors predecessors) #:transparent)

(define (build-program-cfg program)
  (for/list ([func (in-list program)])
    (build-cfg func)))

(define (build-cfg func)
  (unless (and (tagged? func 'func) (>= (length func) 2))
    (error 'cfg "expected a func: ~e" func))
  (define func-name (cadr func))
  (define body (cddr func))

  (define entry-form
    (findf (lambda (x) (and (form? x) (eq? (car x) 'entry))) body))
  (unless entry-form
    (error 'cfg "func ~a: missing entry" (chain->string func-name)))

  (define block-forms
    (filter (lambda (x) (and (form? x) (eq? (car x) 'block))) body))
  (define blocks (map cadr block-forms))

  (define successors (make-hash))
  (for ([block (in-list block-forms)])
    (define block-name (cadr block))
    (define forms (cddr block))
    (define term (last forms))
    (hash-set! successors block-name (term-successors term)))

  (define predecessors (make-hash))
  (for ([block (in-list blocks)])
    (hash-set! predecessors block '()))
  (for ([block (in-list blocks)])
    (for ([succ (in-list (hash-ref successors block))])
      (hash-set! predecessors succ
                 (append (hash-ref predecessors succ) (list block)))))

  (cfg func-name (cadr entry-form) blocks successors predecessors))

;; (term (jump b))         -> (list b)
;; (term (branch c b1 b2)) -> (list b1 b2)
;; (term (return ...))     -> '()
;; (term (trap))           -> '()
(define (term-successors term)
  (match term
    [(list 'term (list 'jump (? symbol? target)))
     (list target)]
    [(list 'term (list 'branch _ (? symbol? then) (? symbol? else)))
     (list then else)]
    [(list 'term (list 'return _ ...))
     '()]
    [(list 'term (list 'trap))
     '()]
    [_ (error 'cfg "malformed term: ~e" term)]))

;; 从 entry 出发的 block，按发现顺序返回。
(define (reachable-blocks c)
  (define seen (make-hash))
  (define order '())
  (let loop ([work (list (cfg-entry c))])
    (cond
      [(null? work) (reverse order)]
      [else
       (define block (car work))
       (cond
         [(hash-has-key? seen block)
          (loop (cdr work))]
         [else
          (hash-set! seen block #t)
          (set! order (cons block order))
          (loop (append (cdr work)
                        (hash-ref (cfg-successors c) block '())))])])))

(define (unreachable-blocks c)
  (define reachable (reachable-blocks c))
  (for/list ([block (in-list (cfg-blocks c))]
             #:unless (member block reachable))
    block))

(define (cfg-all-reachable? c)
  (null? (unreachable-blocks c)))
