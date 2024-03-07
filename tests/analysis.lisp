(defpackage #:breeze.test.analysis
  (:documentation "Tests for the package breeze.analysis")
  (:use #:cl #:breeze.analysis)
  (:import-from #:parachute
                #:define-test
                #:define-test+run
                #:is
                #:true
                #:false
                #:of-type))

(in-package #:breeze.test.analysis)


;;; Integrating pattern.lisp and lossless-parser.lisp

(defun test-match-parse (pattern string &optional skip-whitespaces-and-comments)
  (let* ((state (parse string))
         (*match-skip* (when skip-whitespaces-and-comments
                         #'whitespace-or-comment-node-p)))
    (values (match (compile-pattern pattern) state) state)))

(define-test+run "match pattern nil and (nil) against parse trees"
  ;; pattern nil
  (loop
    :for skip-p :in '(nil t)
    :do (progn
          ;; TODO I'm not sure what should be the right things
          ;;  - on one hand the parse tree _is_ nil
          ;;  - on the other hand, (read "") would error
          ;; (false (test-match-parse nil ""))
          (false (test-match-parse nil "  " skip-p))
          (false (test-match-parse nil "; hi" skip-p))
          (false (test-match-parse nil "#| hi |#" skip-p))
          (false (test-match-parse nil "nil" skip-p))
          (false (test-match-parse nil "NIL" skip-p))
          (false (test-match-parse nil "nIl" skip-p))
          (false (test-match-parse nil "cl:nil" skip-p))
          (false (test-match-parse nil "cl::nil" skip-p))
          (false (test-match-parse nil "common-lisp:nil" skip-p))
          (false (test-match-parse nil "common-lisp::nil" skip-p))
          (false (test-match-parse nil "common-lisp-user::nil" skip-p))
          (false (test-match-parse nil "common-lisp-user:nil" skip-p))))
  (progn
    (false (test-match-parse '(nil) ""))
    (false (test-match-parse '(nil) "  "))
    (false (test-match-parse '(nil) "; hi"))
    (false (test-match-parse '(nil) "#| hi |#"))
    (true (test-match-parse '(nil) "nil"))
    (true (test-match-parse '(nil) "NIL"))
    (true (test-match-parse '(nil) "nIl"))
    (true (test-match-parse '(nil) "cl:nil"))
    (true (test-match-parse '(nil) "cl::nil"))
    (true (test-match-parse '(nil) "common-lisp:nil"))
    (true (test-match-parse '(nil) "common-lisp::nil"))
    ;; TODO For now we don't check _all_ the package a symbol might be
    ;; part of
    (false (test-match-parse '(nil) "common-lisp-user::nil"))
    (false (test-match-parse '(nil) "common-lisp-user:nil")))
  (progn
    (false (test-match-parse '(nil) "" t))
    (false (test-match-parse '(nil) "  " t))
    (false (test-match-parse '(nil) "; hi" t))
    (false (test-match-parse '(nil) "#| hi |#" t))

    (true (test-match-parse '(nil) " nil " t))

    (true (test-match-parse '(nil) " #| t |# NIL" t))
    (true (test-match-parse '(nil) "    nIl" t))
    (true (test-match-parse '(nil) " ;; look ma!
                                    cl:nil" t))
    (true (test-match-parse '(nil) " #||# cl::nil" t))
    (true (test-match-parse '(nil) " #|;;|# common-lisp:nil " t))
    (true (test-match-parse '(nil) " common-lisp::nil " t))
    ;; TODO For now we don't check _all_ the package a symbol might be
    ;; part of
    (false (test-match-parse '(nil) "common-lisp-user::nil" t))
    (false (test-match-parse '(nil) "common-lisp-user:nil" t))))

(define-test+run "match the patterns t and (t) against parse trees"
  ;; These should return nil because we're trying to match 1 symbol
  ;; against a list of nodes (even if that list is empty).
  (loop
    :for skip-p :in '(nil t)
    :do (progn
          (false (test-match-parse t "" skip-p))
          (false (test-match-parse t "  " skip-p))
          (false (test-match-parse t "; hi" skip-p))
          (false (test-match-parse t "#| hi |#" skip-p))
          (false (test-match-parse t "t" skip-p))
          (false (test-match-parse t "T" skip-p))
          (false (test-match-parse t "t" skip-p))
          (false (test-match-parse t "cl:t" skip-p))
          (false (test-match-parse t "cl::t" skip-p))
          (false (test-match-parse t "common-lisp:t" skip-p))
          (false (test-match-parse t "common-lisp::t" skip-p))
          ;; TODO For now we don't check _all_ the package a symbol might be
          ;; part of
          (false (test-match-parse t "common-lisp-user::t" skip-p))
          (false (test-match-parse t "common-lisp-user:t" skip-p))
          (progn
            (false (test-match-parse t "  t" skip-p))
            (false (test-match-parse t "t  " skip-p))
            (false (test-match-parse t "t ; hi" skip-p))
            (false (test-match-parse t "; t " skip-p))
            (false (test-match-parse t "t #| hi |#" skip-p))
            (false (test-match-parse t "#| t |#" skip-p))
            (false (test-match-parse t "#| hi |# t" skip-p)))))
  (progn
    ;; These should return the same thing whether the match is
    ;; skipping comments and whitespaces or not.
    (loop
      :for skip-p :in '(nil t)
      :do (progn
            (false (test-match-parse '(t) "" skip-p))
            (false (test-match-parse '(t) "  " skip-p))
            (false (test-match-parse '(t) "; hi" skip-p))
            (false (test-match-parse '(t) "#| hi |#" skip-p))
            (true (test-match-parse '(t) "t" skip-p))
            (true (test-match-parse '(t) "T" skip-p))
            (true (test-match-parse '(t) "t" skip-p))
            (true (test-match-parse '(t) "cl:t" skip-p))
            (true (test-match-parse '(t) "cl::t" skip-p))
            (true (test-match-parse '(t) "common-lisp:t" skip-p))
            (true (test-match-parse '(t) "common-lisp::t" skip-p))
            ;; TODO For now we don't check _all_ the package a symbol might be
            ;; part of
            (false (test-match-parse '(t) "common-lisp-user::t" skip-p))
            (false (test-match-parse '(t) "common-lisp-user:t" skip-p))))
    (progn
      (false (test-match-parse '(t) "t ; hi"))
      (false (test-match-parse '(t) "t  "))
      (false (test-match-parse '(t) "t #| hi |#"))
      (true (test-match-parse '(t) "t ; hi" t))
      (true (test-match-parse '(t) "t  " t))
      (true (test-match-parse '(t) "t #| hi |#" t))
      (true (test-match-parse '(t) "  t" t))
      (false (test-match-parse '(t) "; '(t) " t))
      (false (test-match-parse '(t) "#| t |#" t))
      (true (test-match-parse '(t) "#| hi |# t" t)))
    (true (test-match-parse '((t)) " (t) " t))))

;; TODO test pattern 1
;; TODO test pattern 'x
;; TODO test pattern :x
;; TODO test pattern "x"
;; TODO test pattern "some-node" (I'll have to think about the syntax)


(define-test+run "match terms against parse trees"
  (progn
    (is equalp (list (term :?x) nil) (test-match-parse :?x ""))
    (is equalp (list (term :?x) nil) (test-match-parse :?x "" t))
    (is equalp
        (list (term :?x) (list (token 0 1)))
        (test-match-parse :?x "x"))
    (is equalp
        (list (term :?x) (list (whitespace 0 1) (token 1 2)))
        (test-match-parse :?x " x"))
    (is equalp
        (list (term :?x) (list (whitespace 0 1) (token 1 2)))
        (test-match-parse :?x " x" t)))
  (progn
    (false (test-match-parse '(:?x) ""))
    (false (test-match-parse '(:?x) "" t))
    (is equalp
        (list (term :?x) (token 0 1))
        (test-match-parse '(:?x) "x"))
    (false (test-match-parse '(:?x) " x"))
    (is equalp
        (list (term :?x) (token 1 2))
        (test-match-parse '(:?x) " x" t))
    (is equalp
        (list (term :?x) (parens 0 4 (list (token 1 3))))
        (test-match-parse '(:?x) "(42)"))
    (is equalp
        (list (term :?x) (token 1 3))
        (test-match-parse '((:?x)) "(42)"))))

(define-test+run "match vector against parse trees"
  (false (test-match-parse 'x "x"))
  (true (test-match-parse #(x) "x"))
  (true (test-match-parse '((x)) "(x)")))


;;; Basic tree inspection

#++ ;; Sanity-check
(mapcar #'read-from-string
        '("in-package"
          "common-lisp:in-package"
          "cl:in-package"
          "cl-user::in-package"
          "common-lisp-user::in-package"))

(defun test-in-package-node-p (string)
  (let* ((state (parse string))
         (node (first (tree state))))
    ;; The funky reader macro and quasiquote is to fuck with slime and
    ;; sly's regex-based search for "(in-package". Without this the
    ;; rest of the file is evaluated in cl-user by slime and sly.
    (let ((package-designator-node
            #.`(,'in-package-node-p state node)))
      (when package-designator-node
        (node-content state package-designator-node)))))

(define-test+run in-package-node-p
  (is equal "x" (test-in-package-node-p "(in-package x)"))
  (is equal ":x" (test-in-package-node-p "(in-package :x)"))
  (is equal "#:x" (test-in-package-node-p "(in-package #:x)"))
  (is equal "\"x\"" (test-in-package-node-p "(in-package \"x\")"))
  (is equal "x" (test-in-package-node-p "( in-package x )"))
  (is equal "x" (test-in-package-node-p "( in-package #| ∿ |# x )"))
  (is equal "x" (test-in-package-node-p "(cl:in-package x)"))
  (is equal "x" (test-in-package-node-p "(cl::in-package x)")))



(define-test find-node
  (is equal
      '((whitespace . 0) (parens . 1) (parens . 1) (parens . 1) (parens . 1)
        (parens . 1) (parens . 1) (parens . 1) (parens . 1) (whitespace . 2))
      (loop :with input = " ( loop ) "
            :with state = (parse input)
            :for i :from 0 :below (length input)
            :for path = (find-node i (tree state))
            :collect (cons (node-type (car path)) (cdr path)))))

(define-test find-path-to-position
  (is equalp
      '((whitespace)
        (parens whitespace)
        (parens whitespace)
        (parens token)
        (parens token)
        (parens token)
        (parens token)
        (parens whitespace)
        (parens)
        (whitespace))
      (loop :with input = " ( loop ) "
            :with state = (parse input)
            :for i :from 0 :below (length input)
            :for path = (find-path-to-position state i)
            :collect
            (mapcar (lambda (path)
                      (node-type (car path)))
                    path)
            #++(list i (length path)))))


;;; Fixing formatting issues...

(defun parens-has-leading-whitespaces-p (node)
  (and (parens-node-p node)
       (whitespace-node-p (first (node-children node)))))

(defun parens-has-trailing-whitespaces-p (node)
  (and (parens-node-p node)
       (whitespace-node-p (alexandria:lastcar (node-children node)))))

(defun cdr-if (condition list)
  (if condition (cdr list) list))

(defun butlast-if (condition list)
  (if condition (butlast list) list))

(defun fix-trailing-whitespaces-inside-parens (node)
  (let ((first-child (parens-has-leading-whitespaces-p node))
        (last-child (parens-has-trailing-whitespaces-p node)))
    (if (or first-child last-child)
        (copy-parens
         node
         :children (butlast-if
                    last-child
                    (cdr-if first-child (node-children node))))
        node)))


(defun test-remove-whitespaces (input output)
  (let* ((input (format nil input))
         (output (format nil output))
         (state (parse input)))
    (breeze.kite:is
     :comparator 'string=
     :form `(unparse ,state nil 'fix-trailing-whitespaces-inside-parens)
     :got (unparse state nil 'fix-trailing-whitespaces-inside-parens)
     :expected output)))

(define-test+run remove-whitespaces
  (test-remove-whitespaces "( )" "()")
  (test-remove-whitespaces "(~%~%~%)" "()")
  (test-remove-whitespaces "(   ) " "() ")
  (test-remove-whitespaces " ( ) " " () ")
  ;; TODO handle indentation levels!
  ;; (test-remove-whitespaces "(;;~%  )" "(;;~% )")
  (test-remove-whitespaces "( x)" "(x)")
  (test-remove-whitespaces "( x )" "(x)"))



;;; Testing the linter

(defun test-lint (buffer-string)
  (lint :buffer-string buffer-string))

(define-test+run lint
  (false (test-lint ""))
  (false (test-lint ";; "))
  (false (test-lint "(in-package :cl-user)"))
  (is equal '((0 56 :warning
               "Package PLEASE-DONT-DEFINE-A-PACKAGE-WITH-THIS-NAME is not currently defined."))
      (test-lint "(in-package please-dont-define-a-package-with-this-name)"))
  (is equalp
      '((1 3 :warning "Extraneous leading whitespaces."))
      (test-lint "(  )"))
  (is equalp
      '((3 4 :warning "Extraneous trailing whitespaces.")
        (1 2 :warning "Extraneous leading whitespaces."))
      (test-lint "( x )")))
