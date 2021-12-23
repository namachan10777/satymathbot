#!/bin/bash

set -eux

ECR_REGISTRY="966924987919.dkr.ecr.ap-northeast-1.amazonaws.com"
REPOS=("nginx" "envoy" "app" "promtail" "prometheus")

function build_and_push {
    local repo="${ECR_REGISTRY}/satymathbot-$1"
    local revision="$(git rev-parse HEAD)"
    docker pull "${repo}":latest || true
    docker build \
        --cache-from "${repo}:latest" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t "${repo}:latest" \
        "$1" 
    docker tag "${repo}:latest" "${repo}:${revision}"
    docker push "${repo}:latest"
    docker push "${repo}:${revision}"
}

for repo in "${REPOS[@]}"; do
    build_and_push "${repo}"
done
