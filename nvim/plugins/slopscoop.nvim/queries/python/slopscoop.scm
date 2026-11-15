; Symbols that deck anchors (path::Name.inner) can name.
; @symbol is the node whose lines the anchor covers; @name its name.
; Names are qualified by the enclosing @symbol nodes.

(function_definition
  name: (identifier) @name) @symbol

(class_definition
  name: (identifier) @name) @symbol

; Module-level and class-level assignments, e.g. SPLITS = (...)
(module
  (expression_statement
    (assignment
      left: (identifier) @name)) @symbol)

(class_definition
  body: (block
    (expression_statement
      (assignment
        left: (identifier) @name)) @symbol))
