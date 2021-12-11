SATYSFI_PATH=/usr/local/bin/satysfi
WORKDIR=/tmp/satymathbot
SATYH_PATH=satysfi/satyh

test.png: src/main.rs
	silicon $< -o $@

.PHONY: dev
dev: test.png
	cargo watch -x 'run -- -b $(SATYH_PATH) -w $(WORKDIR) -s $(SATYH_PATH)'
