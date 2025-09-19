#lang racket

;;
;; Educational Programming Language Prototype
;;
;; This file contains the core implementation of the educational programming
;; language as described in your design document. It includes:
;;   1. The core interpreter for evaluating the language's fundamental constructs.
;;   2. A desugaring mechanism to handle "syntactic sugar" like the 'for' loop.
;;   3. Example usage to demonstrate the language's functionality.
;;

;; -----------------------------------------------------------------------------
;; Section 1: Core Interpreter
;;
;; This section implements the evaluation logic for the core language constructs.
;; It handles expressions, literals, and basic operations. The `eval-expr`
;; function is the heart of the interpreter, taking an expression and an
;; environment, and returning the computed value.
;; -----------------------------------------------------------------------------

(struct exn:unbound-identifier exn:fail ())
(struct exn:invalid-syntax exn:fail ())

;; The main evaluation function for our language.
(define (eval-expr expr env)
  (match expr
    ;; Self-evaluating expressions (literals)
    [(? number? n) n]
    [(? string? s) s]
    [(? boolean? b) b]

    ;; Variable lookup
    [(? symbol? id)
     (let ([value (lookup-variable id env)])
       (if value
           value
           (raise (exn:unbound-identifier
                   (format "unbound identifier: ~a" id)
                   (current-continuation-marks)))))]

    ;; Core Operations & Special Forms
    [`(define ,id ,e)
     (let ([v (eval-expr e env)])
       (add-binding! id v env)
       v)]
    
    [`(letrec ([(,name ,lambda-expr)]) ,body)
     (let ([new-env (extend-env env)])
       ;; Add a placeholder for the recursive function name
       (add-binding! name 'dummy new-env)
       ;; Evaluate the lambda in the new environment so it can be recursive
       (let ([proc (eval-expr lambda-expr new-env)])
         ;; Update the binding with the actual procedure
         (hash-set! (car new-env) name proc)
         ;; Evaluate the body in the new environment
         (eval-expr body new-env)))]

    [`(quote ,datum) datum]

    [`(+ ,e1 ,e2) (+ (eval-expr e1 env) (eval-expr e2 env))]
    [`(- ,e1 ,e2) (- (eval-expr e1 env) (eval-expr e2 env))]
    [`(* ,e1 ,e2) (* (eval-expr e1 env) (eval-expr e2 env))]
    [`(/ ,e1 ,e2) (/ (eval-expr e1 env) (eval-expr e2 env))]
    [`(> ,e1 ,e2) (> (eval-expr e1 env) (eval-expr e2 env))]
    [`(< ,e1 ,e2) (< (eval-expr e1 env) (eval-expr e2 env))]
    [`(= ,e1 ,e2) (= (eval-expr e1 env) (eval-expr e2 env))]

    [`(if ,cond-expr ,then-expr ,else-expr)
     (if (eval-expr cond-expr env)
         (eval-expr then-expr env)
         (eval-expr else-expr env))]
    
    ;; Handle a sequence of expressions
    [(cons 'begin exprs)
     (for/last ([expr (in-list exprs)])
       (eval-expr expr env))]

    ;; Desugaring for 'for' loop (and other constructs) will happen before
    ;; this function is called, so we don't need to handle it here.

    ;; Lambda for functions (a core feature for future expansion)
    [`(lambda (,param) ,body)
     (lambda (arg)
       (let ([new-env (extend-env env)])
         (add-binding! param arg new-env)
         (eval-expr body new-env)))]

    ;; Function Application
    [`(,func-expr ,arg-expr)
     (let ([func (eval-expr func-expr env)]
           [arg (eval-expr arg-expr env)])
       (if (procedure? func)
           (func arg)
           (raise (exn:invalid-syntax
                   (format "not a procedure: ~a" func)
                   (current-continuation-marks)))))]

    ;; Handle unknown expressions
    [_ (raise (exn:invalid-syntax
               (format "invalid syntax: ~a" expr)
               (current-continuation-marks)))]))


;; -----------------------------------------------------------------------------
;; Section 2: Environment Management
;;
;; This section provides functions for managing the environment, which is
;; crucial for variable scope and storage. It uses a simple list of hash
;; tables to represent nested scopes.
;; -----------------------------------------------------------------------------

(define (make-env)
  (list (make-hash)))

(define (extend-env env)
  (cons (make-hash) env))

(define (add-binding! id val env)
  (hash-set! (car env) id val))

(define (lookup-variable id env)
  (for/or ([frame (in-list env)])
    (hash-ref frame id #f)))


;; -----------------------------------------------------------------------------
;; Section 3: Desugaring
;;
;; This section handles the transformation of "syntactic sugar" into core
;; language forms. This is where you'll add more complex user-facing features
;; without complicating the core interpreter.
;; -----------------------------------------------------------------------------

(define (desugar expr)
  (match expr
    ;; First, match specific forms that need transformation, like 'for'.
    ;; This clause must come before the generic list? clause.
    [`(for (,i ,start) ,cond ,update-clause ,body)
     (let ([loop-name (gensym 'loop)])
       `(letrec ([(,loop-name (lambda (,i)
                               (if ,(desugar cond)
                                   (begin ,(desugar body) (,loop-name ,(desugar (second update-clause))))
                                   'done)))])
          (,loop-name ,(desugar start))))]

    ;; Recursive Case: For any other list, desugar each of its elements.
    ;; This allows desugaring to find expressions inside `begin`, `if`, etc.
    [(? list? l)
     (map desugar l)]

    ;; Base Case: If it's not a list (e.g., a number, symbol, boolean),
    ;; it's an "atom" that doesn't need desugaring. Return it as is.
    [other other]))

;; -----------------------------------------------------------------------------
;; Section 4: Main Execution
;;
;; This section provides the main function to run a program. It first desugars
;; the code and then evaluates it.
;; -----------------------------------------------------------------------------

(define (run-program program-source)
  (let ([desugared-program (desugar program-source)]
        [initial-env (make-env)])
    ;; Add a simple print function to the initial environment
    (add-binding! 'print displayln initial-env)
    (eval-expr desugared-program initial-env)))

;; -----------------------------------------------------------------------------
;; Section 5: Example Usage
;;
;; Here are some examples of how to use the language.
;; -----------------------------------------------------------------------------

(printf "--- Running Core Language Examples ---\n")

;; Define a variable and use it in an expression
(run-program '(begin
                (define x 10)
                (if (> x 5) (+ x 2) (- x 2))))

;; Using a lambda function
(run-program '(begin
                (define my-func (lambda (y) (* y 2)))
                (my-func 21)))


(printf "\n--- Running Desugared 'for' Loop Example ---\n")

;; This 'for' loop will be desugared before evaluation.
;; Note: The current 'for' loop desugaring is a simple example.
;; For a more robust implementation, you might want to handle state differently.
;; This example demonstrates the concept.
(run-program '(begin
                (define i 0)
                (for (i 0) (< i 5) (i (+ i 1))
                     (print i))))