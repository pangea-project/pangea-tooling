#!/bin/bash

cd build/build-area

for changes in `ls kde-l10n-*.changes`; do
  dput ubuntu $changes
done
