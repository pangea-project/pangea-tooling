#!/usr/bin/env ruby

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

DIST = ENV.fetch('DIST')

# This is required since some of the build tags have a invalid Docker
# container name inside.
# We can simply replace those characters with a valid char
BUILD_TAG = ENV.fetch('BUILD_TAG').gsub(/[^a-zA-Z0-9._-]/, '-')

c = CI::Containment.new(image: CI::PangeaImage.new(:debian, DIST))
status_code = c.run(Cmd: ARGV)
exit status_code
