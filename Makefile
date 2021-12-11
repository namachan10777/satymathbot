SATYSFI_PATH=/usr/local/bin/satysfi
WORKDIR=/tmp/satymathbot
SATYH_PATH=satysfi/satyh

.PHONY: dev
dev:
	cargo watch -x 'run -- -b $(SATYH_PATH) -w $(WORKDIR) -s $(SATYH_PATH)'
