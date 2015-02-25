#!/bin/bash

set -ex

/var/lib/jenkins/tooling3/kci/build-harness-internal.sh
/var/lib/jenkins/tooling3/ci-tooling/kci/ppa-copy-package.rb
