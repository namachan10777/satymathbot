#!/bin/bash

set -eux

ECR_REGISTRY="966924987919.dkr.ecr.ap-northeast-1.amazonaws.com"
REPOS=("nginx" "envoy" "satysfi" "app")

function build_and_push {
    local repo="${ECR_REGISTRY}/satymathbot-$1"
    local revision="$(git rev-parse HEAD)"
    docker pull "${repo}":latest || true
    if [ "${repo}" = "app" ]; then
        docker build -t "${repo}:${revision}" --cache-from "${repo}:latest" \
            --build-arg "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" \
            --build-arg "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" \
            --build-arg "AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}" \
            "$1" 
    else
        docker build -t "${repo}:${revision}" --cache-from "${repo}:latest" "$1" 
    fi
    docker tag "${repo}:${revision}" "${repo}:latest"
    docker push "${repo}:latest"
    docker push "${repo}:${revision}"
}

for repo in "${REPOS[@]}"; do
    build_and_push "${repo}"
done
