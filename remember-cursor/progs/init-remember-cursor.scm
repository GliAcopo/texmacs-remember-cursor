;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Local "remember cursor" addon for TeXmacs 2.1.4.
;; Saves the cursor position of every local named buffer and restores it when
;; the file is opened again, like Obsidian's remember-cursor-position.
;; State lives in $TEXMACS_HOME_PATH/system/remember-cursor.scm.
;;
;; Copyright (C) 2026 Jacopo Rizzuto
;; This software is released under the GNU General Public License version 3
;; or any later version; see the LICENSE file in the repository.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(plugin-configure remember-cursor
  (:prioritary #t))

(define remember-cursor-enabled? #t)
(define remember-cursor-max-entries 300)

;; buffer key (system path string) -> (timestamp . relative cursor path)
(define remember-cursor-table (make-ahash-table))
(define remember-cursor-dirty? #f)
(define remember-cursor-save-pending? #f)
;; freshly loaded buffers whose saved position has not been restored yet
(define remember-cursor-pending (make-ahash-table))

(define (remember-cursor-file)
  (url-append "$TEXMACS_HOME_PATH" "system/remember-cursor.scm"))

(define-macro (remember-cursor-safe . body)
  `(catch #t (lambda () ,@body) (lambda args #f)))

(define (remember-cursor-buffer? buffer)
  (and buffer
       (buffer-has-name? buffer)
       (not (url-scratch? buffer))
       (not (url-rooted-web? buffer))
       (not (url-rooted-tmfs? buffer))))

(define (remember-cursor-key buffer)
  (url->system buffer))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Persistence
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (remember-cursor-valid-entry? e)
  (and (pair? e) (string? (car e))
       (pair? (cdr e)) (number? (cadr e))
       (list? (cddr e)) (list-and (map integer? (cddr e)))))

(define (remember-cursor-load)
  (remember-cursor-safe
    (with u (remember-cursor-file)
      (when (url-exists? u)
        (with l (load-object u)
          (when (list? l)
            (for (e l)
              (when (remember-cursor-valid-entry? e)
                (ahash-set! remember-cursor-table (car e) (cdr e))))))))))

(define (remember-cursor-entries)
  (let* ((l (ahash-table->list remember-cursor-table))
         (s (sort l (lambda (a b) (> (cadr a) (cadr b))))))
    (if (> (length s) remember-cursor-max-entries)
        (sublist s 0 remember-cursor-max-entries)
        s)))

(define (remember-cursor-save)
  (remember-cursor-safe
    (when remember-cursor-dirty?
      (let* ((l (remember-cursor-entries))
             (f (url->system (url-materialize (remember-cursor-file) "")))
             (tmp (string-append f ".tmp")))
        (set! remember-cursor-table (make-ahash-table))
        (for (e l) (ahash-set! remember-cursor-table (car e) (cdr e)))
        (call-with-output-file tmp
          (lambda (port) (write l port) (newline port)))
        (rename-file tmp f)
        (set! remember-cursor-dirty? #f)))))

(define (remember-cursor-schedule-save)
  (when (not remember-cursor-save-pending?)
    (set! remember-cursor-save-pending? #t)
    (delayed
      (:idle 3000)
      (set! remember-cursor-save-pending? #f)
      (remember-cursor-save))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Recording
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (remember-cursor-relative-path)
  (let* ((r (tree->path (buffer-tree)))
         (c (cursor-path)))
    (and r c (list-starts? c r) (list-tail c (length r)))))

(define (remember-cursor-record)
  (remember-cursor-safe
    (with buffer (current-buffer)
      (when (and remember-cursor-enabled?
                 (remember-cursor-buffer? buffer)
                 ;; do not overwrite the stored position with the start of
                 ;; the document before the restore had a chance to run
                 (not (ahash-ref remember-cursor-pending
                                 (remember-cursor-key buffer))))
        (and-with p (remember-cursor-relative-path)
          (let* ((key (remember-cursor-key buffer))
                 (old (ahash-ref remember-cursor-table key)))
            (when (or (not old) (!= (cdr old) p))
              (ahash-set! remember-cursor-table key (cons (current-time) p))
              (set! remember-cursor-dirty? #t)
              (remember-cursor-schedule-save))))))))

(tm-define (notify-cursor-moved status)
  (former status)
  (remember-cursor-record))

(tm-define (buffer-close name)
  (remember-cursor-safe
    (when (== name (current-buffer)) (remember-cursor-record))
    (ahash-remove! remember-cursor-pending (remember-cursor-key name))
    (remember-cursor-save))
  (former name))

(on-exit
  (remember-cursor-safe
    (remember-cursor-record)
    (remember-cursor-save)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Restoring
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Is p a valid cursor position inside t?
(define (remember-cursor-valid-path? t p)
  (cond ((null? p) #f)
        ((tree-atomic? t)
         (and (null? (cdr p))
              (<= 0 (car p) (string-length (tree->string t)))))
        ((null? (cdr p)) (in? (car p) '(0 1)))
        ((and (>= (car p) 0) (< (car p) (tree-arity t)))
         (remember-cursor-valid-path? (tree-ref t (car p)) (cdr p)))
        (else #f)))

;; Deepest compound subtree of t reachable along p (at least one step down)
(define (remember-cursor-valid-subtree t p)
  (let loop ((t t) (p p) (found #f))
    (if (and (pair? p) (tree-compound? t)
             (>= (car p) 0) (< (car p) (tree-arity t)))
        (with u (tree-ref t (car p))
          (loop u (cdr p) u))
        found)))

(define (remember-cursor-restore buffer)
  (remember-cursor-safe
    (let ((key (remember-cursor-key buffer)))
      (ahash-remove! remember-cursor-pending key)
      (and-with e (ahash-ref remember-cursor-table key)
        (when (and remember-cursor-enabled? (== (current-buffer) buffer))
          (let* ((root (buffer-tree))
                 (r (tree->path root))
                 (p (cdr e)))
            (cond ((remember-cursor-valid-path? root p)
                   (go-to (append r p)))
                  ((remember-cursor-valid-subtree root p)
                   => (lambda (t) (tree-go-to t :start))))))))))

(define (remember-cursor-at-start?)
  (with p (remember-cursor-relative-path)
    (or (not p)
        (== (append (tree->path (buffer-tree)) p)
            (tree->path (buffer-tree) :start)))))

(define (remember-cursor-after-load buffer)
  (ahash-set! remember-cursor-pending (remember-cursor-key buffer) #t)
  (delayed
    (:idle 250)
    (remember-cursor-restore buffer)))

;; Only buffers that did not exist before the call are restored: switching to
;; an already open buffer keeps its cursor.  When the autosave question is
;; asked, loading continues asynchronously and nothing is restored.
(tm-define (load-buffer-main name . opts)
  (let* ((before (remember-cursor-safe (buffer-list)))
         (result (apply former (cons name opts))))
    (remember-cursor-safe
      (with buffer (current-buffer)
        (when (and (not (in? :background opts))
                   (list? before)
                   (remember-cursor-buffer? buffer)
                   (nin? buffer before))
          (remember-cursor-after-load buffer))))
    result))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(remember-cursor-load)

;; Buffers loaded before this plugin was initialized (e.g. from the command
;; line, when plugin initialization is lazy): restore the current one only if
;; its cursor is still at the start.
(remember-cursor-safe
  (with buffer (current-buffer)
    (when (and (remember-cursor-buffer? buffer)
               (remember-cursor-at-start?))
      (remember-cursor-after-load buffer))))
