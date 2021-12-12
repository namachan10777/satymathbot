SATYSFI_PATH=$(shell which satysfi)
PDFTOPPM_PATH=$(shell which pdftoppm)
WORKDIR=/tmp/satymathbot
SATYH_PATH=satysfi/empty.satyh

test.png: src/main.rs
	silicon $< -o $@

.PHONY: dev
dev: test.png
	cargo watch -x 'run -- -b $(SATYSFI_PATH) -w $(WORKDIR) -s $(SATYH_PATH) -p $(PDFTOPPM_PATH)'
