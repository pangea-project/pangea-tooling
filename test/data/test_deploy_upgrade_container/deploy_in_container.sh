#!/bin/sh

set -ex

if grep vivid /etc/apt/sources.list; then
  echo "Testing :: Found vivid in sources.list still!"
  exit 1
fi
. /etc/lsb-release
if [ "$DISTRIB_CODENAME" = "vivid" ]; then
  echo "Testing :: DISTRIB_CODENAME=vivid"
  exit 1
fi
