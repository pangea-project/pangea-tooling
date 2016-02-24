#!/usr/bin/env ruby

require_relative '../lib/ci/build_source'
require_relative 'lib/setup_repo'

DIST = ENV.fetch('DIST')

DCI.setup_repo!
builder = CI::VcsSourceBuilder.new(release: DIST)
builder.run
