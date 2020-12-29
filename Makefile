CMD_DIR=cmd/satymathbot
BINARY=cmd/satymathbot/satymathbot

.PHONY: all clean
all: $(BINARY)

clean:
	rm $(BINARY)

$(BINARY): $(shell find $(CMD_DIR) -type f -name '*.go')
	cd $(CMD_DIR) && go build
