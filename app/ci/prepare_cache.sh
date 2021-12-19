#!/bin/bash

BUCKET="satymathbot-ci-cache"
SHASUM=$(cat Cargo.lock Cargo.toml | shasum -a 256 | awk '{print $1}')

if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    if [aws s3api get-object --bucket "${BUCKET}" --key "${SHASUM}" cache.tar.zst]; then
        tar xf cache.tar.zst
        mv cargo/* ~/.cargo/
    fi
fi