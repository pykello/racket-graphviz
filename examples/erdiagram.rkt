#lang racket

(require file/convertible
         "../lib/erdiagram.rkt")

(define (main)
  (define tables
    `(("product" ("title"
                  "description"
                  "price"))
      ("category" ("title"
                   "description"))
      ("customer" ("firstname"
                   "lastname"
                   "address"))
      ("order" ("customer"
                "status"
                "shipping-method"
                "comments"))
      ("lineitem" ("order"
                   "product"
                   "price"
                   "discount"))
      ("supplier" ("name"))))

  (define relations
    `(("product" "category" 'many 'many)
      ("order" "lineitem" 'one 'many)
      ("lineitem" "product" 'many 'one)
      ("order" "customer" 'many 'one)
      ("supplier" "order" 'one 'many)
      ("lineitem" "supplier" 'many 'one)))

  (define result-pict (er-diagram tables relations))
  (write-bytes (convert result-pict 'svg-bytes))
  
  (exit 0))

(main)