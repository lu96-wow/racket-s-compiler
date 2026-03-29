#lang racket

(require racket/serialize)

(serializable-struct frame (tag table) #:transparent)
(serializable-struct scope (tag parent local-frame imported-frames) #:transparent)
(serializable-struct namespace (current-scope) #:mutable #:transparent)

;; Create a new namespace, optionally from an initial scope.
(define (make-namespace [initial-scope #f])
  (cond
    [initial-scope
     (unless (scope? initial-scope)
       (error "initial-scope must be a scope" initial-scope))
     (namespace initial-scope)]
    [else
     (let* ([global-local-frame (frame #f (hash))]
            [global-scope (scope #f #f global-local-frame '())])
       (namespace global-scope))]))

;; Create a snapshot (shallow copy) of a namespace.
(define (snapshot-namespace source-namespace)
  (unless (namespace? source-namespace)
    (error "source-namespace must be a namespace" source-namespace))
  (namespace (namespace-current-scope source-namespace)))

;; Enter a new nested lexical scope with optional tag.
(define (namespace-push ns [tag #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (or (symbol? tag) (not tag))
    (error "tag must be a symbol or #f" tag))
  (let ([current-scope (namespace-current-scope ns)])
    (set-namespace-current-scope!
     ns (scope tag current-scope #f '()))))

;; Exit the current lexical scope (cannot pop global).
(define (namespace-pop ns)
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (let* ([current (namespace-current-scope ns)]
         [parent (scope-parent current)])
    (if parent
        (set-namespace-current-scope! ns parent)
        (error "cannot pop global scope"))))

;; Define a binding in the current local scope.
(define (namespace-define ns key value)
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (symbol? key)
    (error "key must be a symbol" key))
  (let* ([current-scope (namespace-current-scope ns)]
         [local-frame (scope-local-frame current-scope)])
    (cond
      [(frame? local-frame)
       (let* ([old-table (frame-table local-frame)]
              [new-table (hash-set old-table key value)]
              [new-local-frame (frame #f new-table)]
              [new-scope (scope (scope-tag current-scope)
                                (scope-parent current-scope)
                                new-local-frame
                                (scope-imported-frames current-scope))])
         (set-namespace-current-scope! ns new-scope))]
      [else
       (let* ([new-local-frame (frame #f (hash key value))]
              [new-scope (scope (scope-tag current-scope)
                                (scope-parent current-scope)
                                new-local-frame
                                (scope-imported-frames current-scope))])
         (set-namespace-current-scope! ns new-scope))])))

;; Undefine a binding in the current local scope.
;; Returns the removed value if found, otherwise returns `default`.
(define (namespace-undefine ns key [default #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (symbol? key)
    (error "key must be a symbol" key))
  (let* ([current-scope (namespace-current-scope ns)]
         [local-frame (scope-local-frame current-scope)])
    (cond
      [(not (frame? local-frame))
       default]
      [(hash-has-key? (frame-table local-frame) key)
       (let* ([table (frame-table local-frame)]
              [value (hash-ref table key)]
              [new-table (hash-remove table key)]
              [new-local-frame (frame #f new-table)]
              [new-scope (scope (scope-tag current-scope)
                                (scope-parent current-scope)
                                new-local-frame
                                (scope-imported-frames current-scope))])
         (set-namespace-current-scope! ns new-scope)
         value)]
      [else
       default])))

;; Find a binding by key in the current lexical context.
;; Search order: current local → current imported (left-to-right) → parent scopes.
;; Returns value if found, else `default`.
(define (namespace-find ns key [default #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (symbol? key)
    (error "key must be a symbol" key))
  (let loop ([sc (namespace-current-scope ns)])
    (cond
      [sc
       (let ([local-frame (scope-local-frame sc)])
         (if (and (frame? local-frame)
                  (hash-has-key? (frame-table local-frame) key))
             (hash-ref (frame-table local-frame) key)
             (let ([imported-val
                    (for/or ([frm (in-list (scope-imported-frames sc))])
                      (and (hash-has-key? (frame-table frm) key)
                           (hash-ref (frame-table frm) key)))])
               (if imported-val
                   imported-val
                   (loop (scope-parent sc))))))]
      [else default])))

;; Redefine: copy value of `old-key` (found lexically) to `new-key` in current local scope,
;; then remove `old-key`. If `old-key` is not found, returns `default` and does nothing.
;; If `old-key` and `new-key` are the same symbol, do nothing and return the value.
(define (namespace-redefine ns old-key new-key [default #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (symbol? old-key)
    (error "old-key must be a symbol" old-key))
  (unless (symbol? new-key)
    (error "new-key must be a symbol" new-key))
  (cond
    [(eq? old-key new-key)
     ;; Same key: just return its value if exists, or default
     (namespace-find ns old-key default)]
    [else
     (let ([value (namespace-find ns old-key #f)])
       (if value
           (begin
             (namespace-define ns new-key value)
             (namespace-undefine ns old-key)
             value)
           default))]))

;; Get the root (global) scope of a namespace.
(define (namespace-global-scope ns)
  (let loop ([sc (namespace-current-scope ns)])
    (if (scope-parent sc)
        (loop (scope-parent sc))
        sc)))

;; Provide: extract specified bindings from the GLOBAL SCOPE only.
;; Optional `tag` is applied to the exported namespace's global scope.
;; Returns:
;;   - A new namespace with a clean global scope containing only the provided bindings.
;;   - A list of keys not found in the global scope.
(define (namespace-provide ns keys [tag #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (andmap symbol? keys)
    (error "keys must be a list of symbols" keys))
  (unless (or (symbol? tag) (not tag))
    (error "tag must be a symbol or #f" tag))

  (let* ([global-scope (namespace-global-scope ns)]
         [global-local-frame (scope-local-frame global-scope)]
         [provided-table (make-hash)]
         [missing '()])

    (for ([k (in-list keys)])
      (if (and (frame? global-local-frame)
               (hash-has-key? (frame-table global-local-frame) k))
          (hash-set! provided-table k (hash-ref (frame-table global-local-frame) k))
          (set! missing (cons k missing))))

    (let* ([new-local-frame (frame #f (hash-copy provided-table))]
           ;; Use the provided `tag` for the exported global scope
           [new-global-scope (scope tag #f new-local-frame '())]
           [provided-ns (namespace new-global-scope)])
      (values provided-ns (reverse missing)))))

;; Require: import a provided namespace (from namespace-provide) into current scope.
;; The module's bindings are added to the head of imported-frames (so later requires shadow earlier ones).
(define (namespace-require ns module-ns)
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (namespace? module-ns)
    (error "module-ns must be a namespace" module-ns))

  ;; Extract the module's scope
  (let ([mod-scope (namespace-current-scope module-ns)])
    ;; Validate: must be a root scope (parent = #f)
    (unless (not (scope-parent mod-scope))
      (error "module-ns must be a provided (root) namespace with no parent" module-ns))

    (let* ([mod-local-frame (scope-local-frame mod-scope)]
           [mod-tag (scope-tag mod-scope)])

      ;; Must have a local frame (even if empty)
      (unless (frame? mod-local-frame)
        (error "module-ns must have a local frame" module-ns))

      ;; Build new imported frame: (frame tag table)
      (let* ([imported-frame (frame mod-tag (frame-table mod-local-frame))]
             [current-scope (namespace-current-scope ns)]
             [new-imported-frames (cons imported-frame
                                        (scope-imported-frames current-scope))]
             [new-scope (scope (scope-tag current-scope)
                               (scope-parent current-scope)
                               (scope-local-frame current-scope)
                               new-imported-frames)])
        (set-namespace-current-scope! ns new-scope)))))

;; Unrequire: remove all imported frames with the given module name from current scope.
;; Returns a list of removed frames if any, otherwise returns `default`.
(define (namespace-unrequire ns mod-name [default #f])
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (symbol? mod-name)
    (error "mod-name must be a symbol" mod-name))

  (let* ([current-scope (namespace-current-scope ns)]
         [imported (scope-imported-frames current-scope)]
         [to-remove '()]
         [remaining '()])

    ;; Partition imported frames
    (for ([frm (in-list imported)])
      (if (eq? (frame-tag frm) mod-name)
          (set! to-remove (cons frm to-remove))
          (set! remaining (cons frm remaining))))

    (cond
      [(null? to-remove)
       ;; No matching module found
       default]
      [else
       ;; Rebuild scope without the removed frames
       (let* ([new-scope (scope (scope-tag current-scope)
                                (scope-parent current-scope)
                                (scope-local-frame current-scope)
                                (reverse remaining))] ; preserve original order of others
              [removed-list (reverse to-remove)]) ; restore original order
         (set-namespace-current-scope! ns new-scope)
         removed-list)])))

;; Save a namespace to a file using write (human-readable + serializable).
(define (namespace-save ns path)
  (unless (namespace? ns)
    (error "ns must be a namespace" ns))
  (unless (string? path)
    (error "path must be a string" path))
  (with-output-to-file path
    (lambda () (write ns))
    #:exists 'replace))

;; Load a namespace from a file.
(define (namespace-load path)
  (unless (string? path)
    (error "path must be a string" path))
  (with-input-from-file path read))

(provide
 make-namespace
 snapshot-namespace
 namespace-push
 namespace-pop
 namespace-define
 namespace-undefine
 namespace-find
 namespace-redefine
 namespace-provide
 namespace-require
 namespace-unrequire
 namespace-save
 namespace-load)
