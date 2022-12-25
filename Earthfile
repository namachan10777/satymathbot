VERSION 0.6
IMPORT ./promtail
IMPORT ./prometheus
IMPORT ./envoy
IMPORT ./app
IMPORT ./web

app:
	FROM app+image
	SAVE IMAGE $repo/satymathbot-app:$tag


envoy:
	FROM envoy+image
	SAVE IMAGE $repo/satymathbot-envoy:$tag

web:
	FROM web+image
	SAVE IMAGE $repo/satymathbot-web:$tag

promtail:
	FROM promtail+image
	SAVE IMAGE $repo/satymathbot-promtail:$tag

prometheus:
	FROM prometheus+image
	SAVE IMAGE $repo/satymathbot-prometheus:$tag

images:
	ARG repo=966924987919.dkr.ecr.ap-northeast-1.amazonaws.com
	ARG tag=latest
	BUILD +app        --repo=$repo --tag=$tag
	BUILD +app        --repo=$repo --tag=$tag
	BUILD +envoy      --repo=$repo --tag=$tag
	BUILD +envoy      --repo=$repo --tag=latest
	BUILD +web        --repo=$repo --tag=$tag
	BUILD +web        --repo=$repo --tag=latest
	BUILD +promtail   --repo=$repo --tag=$tag
	BUILD +promtail   --repo=$repo --tag=latest
	BUILD +prometheus --repo=$repo --tag=$tag
	BUILD +prometheus --repo=$repo --tag=latest
