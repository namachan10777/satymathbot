CMD_DIR=cmd/satymathbot
BINARY=$(CMD_DIR)/satymathbot
DOCKER_PROD_DIR=dockerfile/prod
DOCKER_PROD_FILE=$(DOCKER_PROD_DIR)/Dockerfile

GO_SOURCES=$(shell find . -type f -name '*.go')

.PHONY: all clean docker

docker: $(DOCKER_PROD_FILE) $(GO_SOURCES)
	docker build -t satymathbot -f $(DOCKER_PROD_FILE) .

all: $(BINARY)

clean:
	rm $(BINARY)

$(BINARY): $(shell find $(CMD_DIR) -type f -name '*.go')
	cd $(CMD_DIR) && go build
