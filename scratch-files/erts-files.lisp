
(cl:in-package :cl-user)

(defpackage #:breeze.test-file
  (:documentation "Trying to part ERT-like files. (See \"emacs erts files\".)")
  (:use #:cl)
  (:import-from #:alexandria
                #:symbolicate
                #:when-let
                #:make-keyword))

(in-package #:breeze.test-file)

(require 'alexandria)

(defun remove-comment (line)
  (subseq line 0 (position #\; line)))

#++ (progn
      (remove-comment "aasdf")
      (remove-comment "aas;df"))

(defun whitespacep (char)
  "Is CHAR a whitespace?"
  (position char #.(coerce '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return
                             #\Rubout)
                           'string)
            :test #'char=))

(defun trim-whitespace (string)
  (string-trim '(#\Space #\Newline #\Backspace #\Tab #\Linefeed
                 #\Page #\Return #\Rubout)
               string))

(defun null-or-empty-p (seq)
  (or
   (null seq)
   (zerop (length seq))))

(defun emptyp (string)
  (or
   (null-or-empty-p string)
   (every #'whitespacep string)))

(defun not-empty-p (string)
  (if (emptyp string) nil string))

#++ (list
     (not-empty-p "")
     (not-empty-p nil)
     (not-empty-p "  ")
     (not-empty-p " a "))

(defun normalize (line)
  (not-empty-p
   (trim-whitespace
    (remove-comment line))))

(defun string-bool (string)
  (cond
    ((string-equal string "nil") nil)
    ((string-equal string "t") t)
    (t string)))

(defun attributep (line)
  (and line
       (position #\: line)))

(defun attribute (line)
  (and line
       (when-let ((col (position #\: line)))
         (cons
          (alexandria:make-keyword (string-upcase (subseq line 0 col)))
          (string-bool (trim-whitespace (subseq line (1+ col))))))))

(defun start-delimiter-p (string)
  (and string
       (string= string "=-=")))

(defun end-delimiter-p (string)
  (and string
       (string= string "=-=-=")))

(progn
  (defun read-spec-file (pathname)
    (let (specifications
          section
          sections
          start-line-number
          end-line-number
          (attributes (make-hash-table)))
      (flet ((clean-attributes ()
               (remhash :skip attributes))
             (add-spec ()
               (push `(:start ,start-line-number
                       :end ,end-line-number
                       ,@(alexandria:hash-table-plist attributes)
                       ,(nreverse sections))
                     specifications)
               (setf sections nil))
             (add-section ()
               (push (format nil "~{~a~%~}" (nreverse section)) sections)
               (setf section nil)))
        (loop
          :for line :in (uiop:with-safe-io-syntax ()
                          (uiop:read-file-lines pathname))
          :for line-number :from 1
          :for norm = (normalize line)
          :do (if sections
                  (cond
                    ((end-delimiter-p norm)
                     (setf end-line-number line-number)
                     (add-section) (add-spec) (clean-attributes))
                    ((start-delimiter-p norm) (add-section))
                    (t (push line section)))
                  (when norm
                    (or
                     (alexandria:when-let ((attr (attribute norm)))
                       (setf (gethash (car attr) attributes) (cdr attr)))
                     (and (start-delimiter-p norm)
                          (setf sections (list :sections)
                                start-line-number line-number))
                     (error "The line ~s is not empty, but is nor an attribute or a section start." line)))))
        (nreverse specifications))))

  (read-spec-file
   (asdf:system-relative-pathname
    "breeze" "scratch-files/notes/strutural-editing.lisp")))




(defmacro with-collectors ((&rest collectors) &body body)
  "Introduce a set of list with functions to push , get, set, etc those
lists."
  (let* ((variables (mapcar #'(lambda (x) (gensym (symbol-name x))) collectors))
         (labels (loop :for collector :in collectors
                       :for v :in variables
                       :for push = (symbolicate 'push- collector)
                       :for set = (symbolicate 'set- collector)
                       :for drain = (symbolicate 'drain- collector)
                       :append `((,push (x)
                                        (unless (car ,v)
                                          (setf ,v nil))
                                        (let ((new-tail (cons x nil)))
                                          (if ,v
                                              (setf (cddr ,v) new-tail
                                                    (cdr ,v) new-tail)
                                              (setf ,v (cons new-tail new-tail))))
                                        x)
                                 (,set (&optional x)
                                       (unless ,v
                                         (setf ,v (cons nil nil)))
                                       (setf (car ,v) (copy-list x)
                                             (cdr ,v) (last (car ,v)))
                                       x)
                                 ((setf ,collector) (new-value) (,set new-value))
                                 (,drain () (,collector nil))
                                 (,collector (&optional (new-value nil new-value-p))
                                             (if new-value-p
                                                 (prog1 (when ,v (car ,v))
                                                   (,set new-value))
                                                 (when ,v (car ,v))))))))
    `(let ,variables
       (labels
           ,labels
         (declare (ignorable ,@(loop :for (label . rest) :in labels
                                     :collect `(function ,label))))
         ,@body))))

(with-collectors (x)
  (x '(32))
  (x))

(with-collectors (x)
  (x '(32)))

(with-collectors (x)
  (push-x 0)
  (push-x 1)
  (push-x 3)
  (x))

(with-collectors (x y)
  (push-x 0)
  (push-y (copy-list (x)))
  (push-y 4)

  (push-x 1)
  (x '(a b c))
  ;; == (setf (x) '(a b c))
  ;; == (set-x '(a b c))

  (push-x 2)
  (push-x 3)

  (list (x) (y))
  ;; == (mapcar #'funcall (list #'x #'y))
  )
;; => ((A B C 2 3) ((0) 4))

(defmacro with-states ((var &rest states) &body body)
  (let ((preds (mapcar #'(lambda (s) (symbolicate s '-p)) states))
        (states* (mapcar #'(lambda (s) (symbolicate s)) states)))
    `(let ((,var ,(car states)))
       (labels
           ;; is state s?
           (,@(mapcar #'(lambda (s p) `(,p () (eq ',s ,var))) states preds)
            ;; change to state s
            ,@(mapcar #'(lambda (s s*) `(,s* () (setf ,var ',s))) states states*))
         (symbol-macrolet ,(mapcar #'(lambda (s* p) `(,s* (,p))) states* preds)
           ,@body)))))

(with-states (s :start :stop)
  (list (list s (start-p) (stop-p))
        (list s (stop) s)
        (list s (start-p) (stop-p))
        (start)
        (list s (start-p) (stop-p))
        start
        s))

(with-states (s :start :stop)
  (list start stop (stop) stop))

(defmacro with (clauses &body body)
  (loop
    :for clause :in (reverse clauses)
    :for (first . rest) = (if (listp clause)
                              clause
                              (list clause))
    :for symbol-package = (symbol-package first)
    :for symbol-name = (if (or
                            (eq 'with first)
                            (string= "COMMON-LISP"
                                     (package-name symbol-package)))
                           (symbol-name first)
                           (concatenate 'string "WITH-" (symbol-name first)))
    :do
       (multiple-value-bind (with status)
           (find-symbol symbol-name symbol-package)
         (cond
           ((null with)
            (error "Can't find symbol ~A:WITH-~A" (package-name symbol-package) symbol-name))
           ((eq 'with first)
            (setf body `((let ((,(first rest) ,@(when (rest rest)
                                                  `((with ,(rest rest))))))
                           ,@body))))
           ((and (not (eq *package* symbol-package)) (eq :internal status))
            (error "The symbol ~s is interal to ~s" with symbol-package))
           (t (setf body `((,with ,@rest ,@body)))))))
  (car body))

(with
    ((open-file (in "my-file")))
  test)

(with
    ((output-to-string (out)))
  test)

(with
    ((let ((y 42)))
     (with x (output-to-string (out)
                               (format out "hello ~d" y))))
  x)

#+ this-is-shite
(defun read-spec-file (pathname)
  (with
      ((collectors (specifications
                    lines
                    sections))
       (states (state :top :attr :section))
       (let ((line-number 0)
             start-line-number
             (attributes (make-hash-table))))
       (labels
           ((save-line-number ()
              (setf start-line-number line-number))
            (clean-attributes () (remhash :skip attributes))
            (start-lines (line)
              (save-line-number)
              (lines (list line)))
            (get-lines ()
              (push-sections (format nil "~{~a~%~}" (drain-lines))))
            (start-attribute (line)
              (when (attributep line) (start-lines line) (attr)))
            (end-attributes ()
              (destructuring-bind (key . value)
                  (attribute (get-lines))
                (setf (gethash key attributes) (cons value start-line-number))
                (top)))
            (start-section (line)
              (when (start-delimiter-p line)
                (section)
                (save-line-number)))
            (end-section ()
              (push-sections (drain-lines))
              (clean-attributes))
            (end-spec ()
              (push-specifications `(:start ,start-line-number
                                     :end ,line-number
                                     ,@(alexandria:hash-table-plist attributes)
                                     :sections ,(drain-lines)))
              (clean-attributes)
              (top))
            (dispatch (line norm)
              (when norm
                (or
                 (start-attribute norm)
                 (start-section norm)
                 (error "The line ~s is not empty, but is nor an attribute or a section start." line)))))))
    (loop
      :for line :in (uiop:with-safe-io-syntax ()
                      (uiop:read-file-lines pathname))
      :for norm = (normalize line)
      :do
         (incf line-number)
         (cond
           (top (dispatch line norm))
           ((and attr (and norm (whitespacep (char line 0)))
                 (end-attributes)
                 (dispatch line norm)))
           ((and attr (not (start-delimiter-p norm))) (push-lines line))
           ((and attr (start-section norm)) (end-attributes) (section))
           (section
            (cond
              ((end-delimiter-p norm) (end-spec))
              ((start-delimiter-p norm) (end-section))
              ((and norm (string= norm "\\=-=")) (push-lines "=-="))
              (t (push-lines line))))))
    (specifications)))




(defun read-spec-file (pathname)
  (with
      ((open-file (stream pathname))
       (collectors (tests parts))
       (let ((attributes (make-hash-table))
             (eof (gensym "eof"))))
       (macrolet
           ((push-char () `(write-char c out))))
       (labels
           ((peek (&optional (peek-type t))
              (peek-char peek-type stream nil eof))
            (get-char ()  (read-char stream))
            (eofp (x) (eq eof x))
            (clean-attributes () (remhash :skip attributes))
            (trim-last-newline (string)
              (let* ((end (1- (length string))))
                (if (char= #\Newline (char string end))
                    (subseq string 0 end)
                    string)))
            (read-comment (c)
              (when (char= #\; c)
                (read-line stream nil t)))
            (read-string (string)
              (loop :for c :across string
                    :do (char= c (get-char))))
            (read-test (c)
              (when (char= #\= c)
                (with-output-to-string (out)
                  (read-string #. (format nil "=-=~%"))
                  (loop :for line = (read-line stream)
                        :do (cond
                              ((start-delimiter-p line)
                               (push-parts (trim-last-newline (get-output-stream-string out))))
                              ((end-delimiter-p line)
                               (push-parts (trim-last-newline (get-output-stream-string out)))
                               (push-tests `(,@(alexandria:hash-table-plist attributes)
                                             :parts ,(drain-parts)))
                               (peek) ;; skip whitespaces
                               (clean-attributes)
                               (return-from read-test t))
                              ((string= "\\=-=" line)
                               (write-string line out :start 1)
                               (write-char #\newline out))
                              (t (write-string line out)
                                 (write-char #\newline out)))))))
            (read-attribute-name ()
              (make-keyword
               (string-upcase
                (with-output-to-string (out)
                  (loop :for c = (get-char)
                        :until (char= c #\:)
                        :do (write-char c out))))))
            (read-attribute-value ()
              (string-bool
               (trim-whitespace
                (with ((output-to-string (out)))
                  (loop
                    :for nl = nil :then (or (char= #\Linefeed c)
                                            (char= #\Return c))
                    :for c = (peek nil)
                    :until (or (eofp c)
                               (and nl (not (whitespacep c))))
                    :do
                       ;; (format t "~%c = ~s nl = ~s" c nl)
                       (if (read-comment c)
                           (unread-char (setf c #\Return) stream)
                           (write-char (get-char) out)))))))
            (read-attribute ()
              (let ((name (read-attribute-name))
                    (value (read-attribute-value)))
                (setf (gethash name attributes) value))))))
    (loop
      :for c = (peek)
      :repeat 250 ;; guard
      :until (eofp c)
      :for part = (or
                   (whitespacep c)
                   (read-comment c)
                   (read-test c)
                   (read-attribute))
      ;; :do (format t "~&~s" part)
      )
    ;; (format t "~&Final: ~% ~{~s~%~}" (tests))
    (tests)))

(defparameter *structural-editing-tests*
  (read-spec-file
   (asdf:system-relative-pathname
    "breeze" "scratch-files/notes/strutural-editing.lisp")))



(loop :for test :in *structural-editing-tests*
      :do (format t "~&~a: ~a parts"
                  (getf test :name)
                  (length (getf test :parts))
                  )
          ;; :do (print test)
      )
