## Required binaries
OCSIGENSERVER := ocsigenserver.opt

##----------------------------------------------------------------------
## General

PROJECT_NAME          := blibli
DIST_BASE_DIRS := etc lib var/run var/log var/www var/data

DIST_DIRS          := $(addsuffix /blibli,$(DIST_BASE_DIRS))
ELIOMSTATICDIR        := var/www/$(PROJECT_NAME)
JS_PREFIX          := local/$(ELIOMSTATICDIR)/$(PROJECT_NAME)

##----------------------------------------------------------------------
## Testing

.PHONY: test staticfiles

test: build | staticfiles
	mkdir -p $(addprefix local/,$(DIST_DIRS))
	$(OCSIGENSERVER) -c blibli.debug.conf

staticfiles:
	mkdir -p local/var/www
	cp -rf static/css local/$(ELIOMSTATICDIR)

##----------------------------------------------------------------------
## Compilation

.PHONY: gen-dune config-files build

config-files:
	mkdir -p local/lib/$(PROJECT_NAME) local/$(ELIOMSTATICDIR)
	cp -f _build/default/client/$(PROJECT_NAME).bc.js $(JS_PREFIX).js && \
	cp -f _build/default/$(PROJECT_NAME).cmxs local/lib/$(PROJECT_NAME)/

build: gen-dune
	$(ENV_PSQL) dune build $(DUNE_OPTIONS) $(PROJECT_NAME).cmxs @$(PROJECT_NAME)
	make config-files PROJECT_NAME=$(PROJECT_NAME)

gen-dune:
	@ocaml tools/gen_dune.ml > client/dune.client

##----------------------------------------------------------------------
## Clean up

.PHONY: clean

clean::
	dune clean
