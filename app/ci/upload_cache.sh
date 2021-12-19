#!/bin/bash

BUCKET="satymathbot-ci-cache"
SHASUM=$(cat Cargo.lock Cargo.toml | shasum -a 256 | awk '{print $1}')

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    rm -rf cargo
    mkdir -p cargo
    cp -r ~/.cargo/git ~/.cargo/registry cargo
    tar --zst cf cache.tar.zst cargo target
    aws s3api put-object --bucket "${BUCKET}" --key "${SHASUM}" cache.tar.zst
fi