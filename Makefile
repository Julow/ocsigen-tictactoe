gen-dune:
	@ocaml tools/gen_dune.ml > client/dune.client

# The dune rules generate the full project structure in 'dist'.
# Copy it into a different directory to make it mutable.
build: gen-dune
	dune build @blibli
	cp -rT --no-preserve=mode,ownership _build/default/dist local

test: build
	ocsigenserver.opt -c blibli.debug.conf

clean:
	dune clean

.PHONY: build test clean
