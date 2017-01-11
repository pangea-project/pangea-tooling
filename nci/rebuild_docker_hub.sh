#!/bin/bash

set -e

# Trigger Docker image rebuilds https://hub.docker.com/r/kdeneon/plasma/~/settings/automated-builds/
# To be run by daily mgmt job

. ~/docker-token

curl --data build=true -X POST https://registry.hub.docker.com/u/kdeneon/plasma/trigger/${PLASMA_TOKEN}/

curl --data build=true -X POST https://registry.hub.docker.com/u/kdeneon/all/trigger/${ALL_TOKEN}/
