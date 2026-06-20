.PHONY: serve test smoke service-smoke

PORT ?= 8199

serve:
	python3 -m http.server $(PORT)

test:
	bash -n node.sh
	bash -n scripts/smoke-node.sh
	python3 -m http.server 0 >/tmp/ifuri-get-test.log 2>&1 & echo $$! > /tmp/ifuri-get-test.pid
	kill "$$(cat /tmp/ifuri-get-test.pid)"

smoke:
	bash scripts/smoke-node.sh

service-smoke:
	bash scripts/smoke-service.sh

.PHONY: deploy
deploy: ## Publish to get.ifuri.com (Plesk)
	bash scripts/deploy-plesk.sh
