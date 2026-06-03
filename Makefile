SHELL := /bin/bash

SSH_HOST ?= yandex-relay
DECOY_DIST ?= PlitkaKlal/site/dist
REMOTE_DECOY ?= /var/www/decoy
PREVIEW_PORT ?= 4321

.PHONY: help validate validate-haproxy validate-compose status list-decoy preview-decoy diff-decoy pull-decoy

help:
	@printf '%s\n' 'mtproto-faketls-stack'
	@printf '%s\n' ''
	@printf '%s\n' 'Targets:'
	@printf '%s\n' '  make validate         Run available local config checks'
	@printf '%s\n' '  make status           Show git status and ignored decoy state'
	@printf '%s\n' '  make list-decoy       List local decoy dist files'
	@printf '%s\n' '  make preview-decoy    Serve local decoy dist on 127.0.0.1:4321'
	@printf '%s\n' '  make diff-decoy       Dry-run compare server decoy to local dist'
	@printf '%s\n' '  make pull-decoy       Sync server decoy build into local dist'

validate: validate-haproxy validate-compose

validate-haproxy:
	@if command -v haproxy >/dev/null 2>&1; then \
		haproxy -c -f deploy/haproxy/haproxy.cfg; \
	else \
		printf '%s\n' 'skip: haproxy is not installed locally'; \
	fi

validate-compose:
	@if command -v docker >/dev/null 2>&1; then \
		docker compose -f deploy/telemt/docker-compose.yml config >/dev/null; \
		printf '%s\n' 'ok: deploy/telemt/docker-compose.yml'; \
	else \
		printf '%s\n' 'skip: docker is not installed locally'; \
	fi

status:
	@git status --short
	@git status --short --ignored=matching PlitkaKlal .gitignore

list-decoy:
	@find "$(DECOY_DIST)" -maxdepth 2 -type f | sort

preview-decoy:
	@python3 -m http.server "$(PREVIEW_PORT)" --bind 127.0.0.1 --directory "$(DECOY_DIST)"

diff-decoy:
	@rsync -ani --delete "$(SSH_HOST):$(REMOTE_DECOY)/" "$(DECOY_DIST)/"

pull-decoy:
	@mkdir -p "$(DECOY_DIST)"
	@rsync -a --delete "$(SSH_HOST):$(REMOTE_DECOY)/" "$(DECOY_DIST)/"
