#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/ci/package_builder'
require_relative '../lib/apt'

builder = CI::PackageBuilder.new
builder.build
