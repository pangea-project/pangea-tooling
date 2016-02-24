#!/usr/bin/env ruby

require_relative '../lib/ci/build_binary'
require_relative 'lib/setup'

builder = CI::PackageBuilder.new
builder.build
