#lang racket/base

(define extensions
  '(rv32_c rv32_c_f rv32_d_zfa rv32_i rv32_zbb rv32_zbkb rv32_zbs rv32_zclsd rv32_zicntr rv32_zilsd rv32_zk rv32_zkn rv32_zknd rv32_zkne rv32_zknh rv32_zks rv64_a rv64_c rv64_d rv64_f rv64_h rv64_i rv64_m rv64_q rv64_q_zfa rv64_zacas rv64_zba rv64_zbb rv64_zbkb rv64_zbs rv64_zcb rv64_zfh rv64_zk rv64_zkn rv64_zknd rv64_zkne rv64_zknh rv64_zks rv_a rv_c rv_c_d rv_c_zicfiss rv_c_zihintntl rv_d rv_d_zfa rv_d_zfhmin rv_f rv_f_zfa rv_h rv_i rv_m rv_q rv_q_zfa rv_q_zfhmin rv_s rv_sdext rv_smrnmi rv_ssctr rv_svinval rv_svinval_h rv_system rv_v rv_v_aliases rv_zabha rv_zabha_zacas rv_zacas rv_zalasr rv_zawrs rv_zba rv_zbb rv_zbc rv_zbkb rv_zbkc rv_zbkx rv_zbs rv_zcb rv_zcmop rv_zcmp rv_zcmt rv_zfbfmin rv_zfh rv_zfh_zfa rv_zfhmin rv_zicbo rv_zicfilp rv_zicfiss rv_zicntr rv_zicond rv_zicsr rv_zifencei rv_zihintntl rv_zimop rv_zk rv_zkn rv_zknh rv_zks rv_zksed rv_zksh rv_zvbb rv_zvbc rv_zvfbfmin rv_zvfbfwma rv_zvkg rv_zvkn rv_zvkned rv_zvknha rv_zvknhb rv_zvks rv_zvksed rv_zvksh))

(provide
 extensions)
