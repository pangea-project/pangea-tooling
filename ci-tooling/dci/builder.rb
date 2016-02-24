#!/usr/bin/env ruby

require_relative '../lib/ci/build_binary'
require_relative 'lib/setup_repo'

DCI.setup_repo!
builder = CI::PackageBuilder.new
builder.build
