SATYSFI_PATH=$(shell which satysfi)
PDFTOPPM_PATH=$(shell which pdftoppm)
WORKDIR=/tmp/satymathbot
SATYH_PATH=satysfi/empty.satyh

.PHONY: dev
dev:
	cargo watch -x 'run -- -b $(SATYSFI_PATH) -w $(WORKDIR) -s $(SATYH_PATH) -p $(PDFTOPPM_PATH)'

docker-compose-core.yml: docker-compose/core.jsonnet docker-compose/core-services.libsonnet
	jsonnet $< > $@

docker-compose-metrics.yml: docker-compose/metrics.jsonnet docker-compose/core-services.libsonnet
	jsonnet $< > $@

.PHONY: docker-compose-core
docker-compose-core: docker-compose-core.yml
	docker-compose -f $< up --build

.PHONY: docker-compose-metrics
docker-compose-metrics: docker-compose-metrics.yml
	docker-compose -f $< up --build

.PHONY: clean
clean:
	rm -f docker-compose-*.yml
	rm -rf target
