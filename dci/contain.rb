#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 36 * 60 * 60 # 36 hours. Because, QtWebEngine.

DIST = ENV.fetch('DIST')
BUILD_TAG = ENV.fetch('BUILD_TAG')

c = CI::Containment.new(BUILD_TAG, image: CI::PangeaImage.new(:debian, DIST))
status_code = c.run(Cmd: ARGV)
exit status_code
