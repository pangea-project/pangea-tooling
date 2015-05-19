#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/ci/build-source'

RELEASE = ENV.fetch('RELEASE')

s = VcsSource.new
s.run(series: RELEASE)
