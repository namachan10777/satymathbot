VERSION 0.6
IMPORT ./promtail
IMPORT ./prometheus
IMPORT ./envoy
IMPORT ./app
IMPORT ./web

app:
	ARG repo
	ARG tag
	FROM app+image
	SAVE IMAGE --push $repo/satymathbot-app:$tag


envoy:
	ARG repo
	ARG tag
	FROM envoy+image
	SAVE IMAGE --push $repo/satymathbot-envoy:$tag

web:
	ARG repo
	ARG tag
	FROM web+image
	SAVE IMAGE --push $repo/satymathbot-web:$tag

promtail:
	ARG repo
	ARG tag
	FROM promtail+image
	SAVE IMAGE --push $repo/satymathbot-promtail:$tag

prometheus:
	ARG repo
	ARG tag
	FROM prometheus+image
	SAVE IMAGE --push $repo/satymathbot-prometheus:$tag

images:
	ARG repo=966924987919.dkr.ecr.ap-northeast-1.amazonaws.com
	ARG tag=latest
	BUILD +app        --repo=$repo --tag=$tag
	BUILD +app        --repo=$repo --tag=latest
	BUILD +envoy      --repo=$repo --tag=$tag
	BUILD +envoy      --repo=$repo --tag=latest
	BUILD +web        --repo=$repo --tag=$tag
	BUILD +web        --repo=$repo --tag=latest
	BUILD +promtail   --repo=$repo --tag=$tag
	BUILD +promtail   --repo=$repo --tag=latest
	BUILD +prometheus --repo=$repo --tag=$tag
	BUILD +prometheus --repo=$repo --tag=latest
