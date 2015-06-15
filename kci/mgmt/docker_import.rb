#!/usr/bin/env ruby

require 'docker'
require 'logger'
require 'logger/colors'

$stdout = $stderr

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

@log = Logger.new(STDERR)

@log.info "Importing #{ARGV[0]}"
Docker::Image.import(ARGV[0])
@log.info 'Done'
