#!/bin/bash

set -ex

# Trigger Docker image rebuilds https://hub.docker.com/r/kdeneon/plasma/~/settings/automated-builds/
# To be run by daily mgmt job

# This file is in format
# PLASMA_TOKEN=xxxx-xxx-xxx-xxxxx
# ALL_TOKEN=xxxx-xxx-xxx-xxxxx
# Token comes from https://cloud.docker.com/u/kdeneon/repository/docker/kdeneon/all/hubbuilds
# and https://cloud.docker.com/u/kdeneon/repository/docker/kdeneon/plasma/hubbuilds

. ~/docker-token

curl -H "Content-Type: application/json" --data '{"build": true}' -X POST https://registry.hub.docker.com/u/kdeneon/plasma/trigger/${PLASMA_TOKEN}/

curl -H "Content-Type: application/json" --data '{"build": true}' -X POST https://registry.hub.docker.com/u/kdeneon/all/trigger/${ALL_TOKEN}/
