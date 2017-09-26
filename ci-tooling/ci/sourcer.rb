#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/ci/build_source'

DIST = ENV.fetch('DIST')

builder = CI::VcsSourceBuilder.new(release: DIST)
builder.run
