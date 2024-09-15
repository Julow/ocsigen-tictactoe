# The dune rules generate the full project structure in 'dist'.
# Copy it into a different directory to make it mutable.
build:
	dune build @blibli
	cp -rT --no-preserve=mode,ownership _build/default/dist local

test: build
	dune exec -- blibli

clean:
	dune clean

.PHONY: build test clean
