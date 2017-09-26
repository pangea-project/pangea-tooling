#!/usr/bin/env ruby
# frozen_string_literal: true

require 'docker'
require 'logger'
require 'logger/colors'

$stdout = $stderr

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

@log = Logger.new(STDERR)

@log.info "Importing #{ARGV[0]}"
image = Docker::Image.import(ARGV[0])
image.tag(repo: 'jenkins/wily_unstable', tag: 'latest', force: true)
@log.info 'Done'
