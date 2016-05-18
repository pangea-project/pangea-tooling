#!/usr/bin/env ruby

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 5 * 60 * 60 # 5 hours.

DIST = ENV.fetch('DIST')
BUILD_TAG = ENV.fetch('BUILD_TAG')

c = CI::Containment.new(BUILD_TAG, image: CI::PangeaImage.new(:debian, DIST))
status_code = c.run(Cmd: ARGV)
exit status_code
