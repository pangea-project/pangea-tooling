#!/usr/bin/env ruby

require_relative '../ci-tooling/lib/ci/build_source'

RELEASE = ENV.fetch('RELEASE')

s = VcsSourceBuilder.new(series: RELEASE)
s.run
