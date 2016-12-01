#!/usr/bin/env ruby

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 36 * 60 * 60 # 36 hours. Because, QtWebEngine.

DIST = ENV.fetch('DIST')
BUILD_TAG = ENV.fetch('BUILD_TAG')

c = CI::Containment.new(BUILD_TAG, image: 'debian:stable', Cmd: ARGV)
status_code = c.run
exit status_code
