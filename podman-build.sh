#!/usr/bin/env bash

mkdir -p $PWD/work

podman build \
    --pull=always \
    --volume $PWD/work:/mnt:rw,z \
    -t localhost/recovery-builder:latest \
    container
