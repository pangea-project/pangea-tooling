#!/usr/bin/env ruby

ENV['LC_ALL'] = 'C.UTF-8'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require_relative "dci/#{ARGV[0]}"

