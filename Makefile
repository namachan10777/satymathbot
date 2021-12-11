RUST_SOURCES=Cargo.lock Cargo.toml $(shell find -type f -name '*.rs' src)
SATYSFI_PATH=/usr/local/bin/satysfi
WORKDIR=/tmp/satymathbot
SATYH_PATH=satysfi/satyh

target/debug/satymathbot: $(RUST_SOURCES)
	cargo build

.PHONY: dev
dev: target/debug/satymathbot
	./target/debug/satymathbot -b $(SATYH_PATH) -w $(WORKDIR) -s $(SATYH_PATH)