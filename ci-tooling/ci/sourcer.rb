#!/usr/bin/env ruby
require_relative '../lib/ci/build_source'

DIST = ENV.fetch('DIST')

builder = CI::VcsSourceBuilder.new(release: DIST)
builder.run
