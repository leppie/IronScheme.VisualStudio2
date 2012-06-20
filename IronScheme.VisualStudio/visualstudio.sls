﻿
(library (visualstudio)
  (export 
    run-expansion
    read-file
    get-forms
    read-imports
    get-error)
  (import 
    (ironscheme)
    (ironscheme reader))

  (define (read-definitions subst env)
    (let ((lookup (make-eq-hashtable))
          (bindings (make-eq-hashtable)))
      (for-each (lambda (x)
                  (hashtable-set! lookup (cdr x) (car x)))
                subst)
      (for-each (lambda (x)
                  (let ((type (cadr x)))
                    (case type
                      [(global global-macro $rtd) 
                        (hashtable-set! bindings 
                                        (hashtable-ref lookup (car x) #f)
                                        type)])))
                env)
      (hashtable-entries bindings)))

  (define (run-expansion e)
    (call-with-values 
      (lambda ()
        (if (null? (cdr e))
            (let-values (((name ver imp* b*) (parse-library (car e))))
              (let-values (((lib* invoke-code macro* export-subst export-env) 
                            (top-level-expander (cons (cons 'import imp*) b*))))
                (values export-subst export-env)))
            (let-values (((lib* invoke-code macro* export-subst export-env) (top-level-expander e)))
              (values export-subst export-env))))
      read-definitions))

  (define (read-file port)
    (let f ((a '()))
      (let ((e (read-annotated port)))
        (if (eof-object? e)
            (reverse a)
            (f (cons e a))))))

  (define (get-location con)
    (let ((rtd (record-rtd con)))
      (if (eq? (record-type-name rtd) '&source-information)
          ((record-accessor rtd 1) con)
          #f)))

  (define (condition-location conds)
    (exists get-location (simple-conditions conds)))

  (define (get-error conds)
    (values (condition-message conds) (condition-location conds)))

  (define (get-forms proc)
    (let-values (((p e) (open-string-output-port)))
      (for-each (lambda (f)
                  (fprintf p "~a\n" f))
                (call-with-values (lambda () (procedure-form proc)) list))
      (e)))
            
  (define (read-imports content)
    (if (null? (cdr content))
        (let-values (((name ver imp* b*) (parse-library (car content))))
          imp*)
        (let-values (((imp* b*) (parse-top-level-program content)))
          imp*))))
