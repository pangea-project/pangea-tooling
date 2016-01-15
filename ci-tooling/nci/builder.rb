#!/usr/bin/env ruby

require_relative 'lib/setup_repo'
require_relative '../lib/ci/build_binary'

NCI.setup_repo!

builder = CI::PackageBuilder.new
builder.build
