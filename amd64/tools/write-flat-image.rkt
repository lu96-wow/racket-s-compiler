#lang racket
;;; amd64/tools/write-flat-image.rkt
;;;
;;; 把 encode 层的缓存写成一个**平铺镜像**（裸机 multiboot 用，没有 ELF 头）。
;;;
;;; 用法：
;;;   racket tools/write-flat-image.rkt <encode 缓存> <输出镜像>
;;;
;;; 缓存由 tools/loko-flow.rkt 产出（<cache-dir>/encode.rktd）。
;;;
;;; 布局规则：段自带地址；按地址顺序把有字节的段摊平，段之间的空隙填 0
;;; （multiboot 加载器加载的是文件里的连续字节，空隙必须真的存在）。
;;; hole 段（bss）不产生文件字节。
;;;
;;; 写完会核对 multiboot v1 头（偏移 8 处的 0x1BADB002）：
;;;   magic / magic+flags+checksum=0 / load_addr=镜像起点 / load_end_addr=有字节段的末尾
;;;   / bss_end_addr=hole 段末尾 / entry_addr 落在 text 段内
;;; 这几条是"布局和头部对得上"的不变式，比启动一次 QEMU 便宜得多。
(require racket/cmdline
         racket/serialize)

(define (field s k)
  (define p (assq k (cdr s)))
  (and p (cadr p)))

(define (u32 b i)
  (+ (bytes-ref b i) (* 256 (bytes-ref b (+ i 1)))
     (* 65536 (bytes-ref b (+ i 2))) (* 16777216 (bytes-ref b (+ i 3)))))

(define (u64 b i) (+ (u32 b i) (* 4294967296 (u32 b (+ i 4)))))

;; multiboot v1 头: (magic flags checksum header_addr load_addr load_end bss_end entry)
(define (read-multiboot-header img origin)
  (define at (- origin origin))       ; 镜像起点就是 image-address-zero
  (define magic (u32 img (+ at 8)))
  (unless (= magic #x1BADB002)
    (error 'write-flat-image
           "multiboot magic mismatch at image start: #x~x (expected #x1badb002)"
           magic))
  (define flags (u32 img (+ at 12)))
  (define checksum (u32 img (+ at 16)))
  ;; multiboot v1: magic + flags + checksum ≡ 0 (mod 2^32)
  (unless (zero? (modulo (+ magic flags checksum) (expt 2 32)))
    (error 'write-flat-image
           "multiboot checksum is wrong: magic=#x~x flags=#x~x checksum=#x~x"
           magic flags checksum))
  (list (list 'flags flags)
        (list 'header_addr (u32 img (+ at 20)))
        (list 'load_addr (u32 img (+ at 24)))
        (list 'load_end_addr (u32 img (+ at 28)))
        (list 'bss_end_addr (u32 img (+ at 32)))
        (list 'entry_addr (u32 img (+ at 36)))))

(define (load-build cache-path)
  (define entries
    (call-with-input-file cache-path (lambda (in) (deserialize (read in)))))
  (define p (assq 'build (for/list ([e (in-list entries)]) (cons (car e) (cadr (cdr e))))))
  (unless p (error 'write-flat-image "cache has no encode output: ~a" cache-path))
  (cdr p))

(command-line
 #:program "write-flat-image"
 #:args (cache-path out-path)
 (define build (load-build cache-path))
 (define segments (cdr build))
 (for ([s (in-list segments)])
   (printf "  ~a kind=~a start=#x~x size=~a bytes=~a\n"
           (field s 'name) (field s 'kind) (field s 'start) (field s 'size)
           (bytes-length (field s 'bytes))))

 ;; 只有带字节的段进文件；hole 只在内存里占位。
 (define placed (sort (filter (lambda (s) (positive? (bytes-length (field s 'bytes)))) segments)
                      < #:key (lambda (s) (field s 'start))))
 (unless (pair? placed) (error 'write-flat-image "no materialized segments"))
 (define origin (field (car placed) 'start))
 (define end (for/fold ([e 0]) ([s (in-list placed)])
               (max e (+ (field s 'start) (bytes-length (field s 'bytes))))))
 (define buf (make-bytes (- end origin) 0))
 (for ([s (in-list placed)])
   (bytes-copy! buf (- (field s 'start) origin) (field s 'bytes)))
 (call-with-output-file out-path #:exists 'replace
   (lambda (o) (write-bytes buf o)))
 (printf "wrote ~a: ~a bytes (origin #x~x, end #x~x)\n"
         out-path (bytes-length buf) origin end)

 ;; 头部不变式
 (define hdr (read-multiboot-header buf origin))
 (define (h k) (cadr (assq k hdr)))
 (define load-end (for/fold ([e origin]) ([s (in-list placed)])
                    (max e (+ (field s 'start) (bytes-length (field s 'bytes))))))
 (define hole (for/first ([s (in-list segments)] #:when (eq? (field s 'kind) 'hole)) s))
 (unless (= (h 'load_addr) origin)
   (error 'write-flat-image "load_addr #x~x != image origin #x~x"
          (h 'load_addr) origin))
 (unless (= (h 'load_end_addr) load-end)
   (error 'write-flat-image "load_end_addr #x~x != end of materialized bytes #x~x"
          (h 'load_end_addr) load-end))
 (when hole
   (unless (= (h 'bss_end_addr) (+ (field hole 'start) (field hole 'size)))
     (error 'write-flat-image "bss_end_addr #x~x != end of hole segment #x~x"
            (h 'bss_end_addr) (+ (field hole 'start) (field hole 'size))))
   (unless (= (h 'load_end_addr) (field hole 'start))
     (error 'write-flat-image
            "load_end_addr #x~x != start of hole segment #x~x (unpadded gap?)"
            (h 'load_end_addr) (field hole 'start))))
 (for ([k (in-list '(flags header_addr load_addr load_end_addr bss_end_addr entry_addr))])
   (printf "  header ~a = #x~x\n" k (h k))))
