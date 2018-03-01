# -*- mode: makefile; tab-width: 8; indent-tabs-mode: 1 -*-
# vim: ts=8 sw=8 ft=make noet

default: all

.PHONY: all

all: stable

.PHONY: test

test: test-9.3 test-9.4 test-9.5 test-9.6 test-10

.PHONY: test-%

test-%: nanobox/postgresql-%
	stdbuf -oL test/run_all.sh $(subst test-,,$@)

.PHONY: nanobox/postgresql-%

nanobox/postgresql-%:
	docker pull $(subst -,:,$@) || (docker pull $(subst -,:,$@)-beta; docker tag $(subst -,:,$@)-beta $@)


.PHONY: stable beta alpha

stable:
	@./util/publish.sh stable

beta:
	@./util/publish.sh beta

alpha:
	@./util/publish.sh alpha