#!/usr/bin/env bash

mkdir -p $PWD/work
mkdir -p $PWD/cache

podman build \
    --pull=always \
    --volume $PWD/work:/mnt:rw,z \
    --volume $PWD/cache:/var/cache:rw,z \
    -t localhost/recovery-builder:latest \
    container
