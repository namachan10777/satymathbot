definition.json: definition.jsonnet
	jsonnet $< > $@

.PHONY: plan
plan: definition.json
	terraform plan


.PHONY: apply
apply: definition.json
	terraform apply
