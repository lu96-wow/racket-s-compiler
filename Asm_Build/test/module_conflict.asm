;; ============================================================
;; 同名导出测试：A 和 B 都导出 C，D 用 A 的 C，E 用 B 的 C
;; 预期：不冲突，各自使用各自的 C
;; ============================================================
(asm rv64 (rv_i)

  ;; ---- 模块 A：导出 C → a0 + 1 ----
  (module A
    (provide C)
    (label C)
    (addi a0 a0 1)
    (jalr zero ra 0))

  ;; ---- 模块 B：导出 C → a0 + 10 ----
  (module B
    (provide C)
    (label C)
    (addi a0 a0 10)
    (jalr zero ra 0))

  ;; ---- 模块 D：require A 的 C，封装为 do-a ----
  (module D
    (require A C)
    (provide do-a)
    (label do-a)
    (jal ra C)
    (jalr zero ra 0))

  ;; ---- 模块 E：require B 的 C，封装为 do-b ----
  (module E
    (require B C)
    (provide do-b)
    (label do-b)
    (jal ra C)
    (jalr zero ra 0))

  ;; ---- main：同时使用 D 和 E ----
  (require D do-a)
  (require E do-b)

  (label main)
  (li a0 0)
  (jal ra do-a)          ;; a0 = 0 + 1 = 1
  (jal ra do-b)          ;; a0 = 1 + 10 = 11
  (ebreak))
