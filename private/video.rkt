#lang racket/base

(provide (all-defined-out))
(require racket/dict
         racket/match
         racket/set
         "mlt.rkt"
         (for-syntax racket/base
                     racket/list
                     racket/syntax
                     syntax/parse))

;; Video tag
(define (tag-video v tag)
  (set-add! (video-tag v) tag)
  v)
(define (find-tag v tag)
  (if (set-member? (video-tag v) tag)
      v
      (match v
        [(struct* link ([source source]
                        [target target]))
         (or (find-tag source) (find-tag target))]
        [else (error 'find-tag "Not currently supported for video type: ~a" v)])))

;; Constructor for video objects
(define-syntax subclass-empty '(() . ()))
(define-syntax (define-constructor stx)
  (syntax-parse stx
    [(_ name:id super*:id [ids:id default] ...)
     #:with constructor (format-id stx "make-~a" #'name)
     #:with new-supers (format-id stx "subclass-~a" #'name)
     #:with super (format-id stx "subclass-~a" #'super*)
     (define super-vals (syntax-local-value #'super))
     (define all-ids (append (car super-vals) (syntax->datum #'(ids ...))))
     (define all-defaults (append (cdr super-vals) (syntax-e #'(default ...))))
     #`(begin
         (define (constructor #,@(append*
                                  (for/list ([i (in-list all-ids)]
                                             [j (in-list all-defaults)])
                                    `(,(datum->syntax stx (string->keyword (symbol->string i)))
                                      [,i ,j]))))
           (define ret (name #,@all-ids))
           ret)
         (define-syntax new-supers '#,(cons all-ids all-defaults)))]))

;; Structs
(struct video ([mlt-object #:mutable] tag))
(define-constructor video empty [mlt-object #f] [tag (mutable-set)])
(struct link video (source target index))
(define-constructor link video [source #f] [target #f] [index 0])
(struct properties video (prop))
(define-constructor properties video [prop (hash)])
(define (properties-ref dict key
                        [default-type 'string])
  (dict-ref (properties-prop dict) key
            (λ ()
              (define v (video-mlt-object dict))
              (unless v
                (error 'properties "MLT object for ~a not created, cannot get default property" dict))
              (define ret
                (match default-type
                  ['string (mlt-properties-get v key)]
                  ['int (mlt-properties-get-int v key)]
                  ['int64 (mlt-properties-get-int64 v key)]
                  ['mlt-position (mlt-properties-get-position v key)]
                  ['double (mlt-properties-get-double v key)]
                  [else (error 'properties "Not a valid default-type ~a" default-type)]))
              ret)))
(struct anim-property video (value position length))
(define-constructor anim-property video [value #f] [position #f] [length #f])
(struct frame properties ())
(define-constructor frame properties)
(struct service properties (filters))
(define-constructor service properties [filters '()])
(struct filter service (type source))
(define-constructor filter service [type #f] [source #f])
(struct transition service (type source length))
(define-constructor transition service [type #f] [source #f] [length #f])
(struct consumer service (type target))
(define-constructor consumer service [type #f] [target #f])
(struct producer service (type source start end speed seek))
(define-constructor producer service [type #f] [source #f] [start #f] [end #f] [speed #f] [seek #f])
(struct playlist producer (elements))
(define-constructor playlist producer [elements '()])
(struct playlist-producer video (producer start end))
(define-constructor playlist-producer video [producer #f] [start #f] [end #f])
(struct blank video (length))
(define-constructor blank video [length 0])
(struct tractor producer (multitrack field))
(define-constructor tractor producer [multitrack (make-multitrack)] [field (make-field)])
(struct multitrack producer (tracks))
(define-constructor multitrack producer [tracks '()])
(struct field video (field-elements))
(define-constructor field video [field-elements '()])
(struct field-element video (element track track-2))
(define-constructor field-element video [element #f] [track #f] [track-2 #f])