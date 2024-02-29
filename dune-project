(lang dune 3.7)

(dialect
 (name "eliom-server")
 (implementation
  (extension "eliom"))
 (interface
  (extension "eliomi")))

(wrapped_executables false)

(using directory-targets 0.1)

(formatting
 (enabled_for ocaml "eliom-server" dune))
