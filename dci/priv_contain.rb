#!/usr/bin/env ruby

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

DIST = ENV.fetch('DIST')

# This is required since some of the build tags have a invalid Docker
# container name inside.
# We can simply replace those characters with a valid char
BUILD_TAG = ENV.fetch('BUILD_TAG').gsub(/\W/, '-')

c = CI::Containment.new(BUILD_TAG,
                        image: CI::PangeaImage.new(:debian, DIST),
                        privileged: true)
status_code = c.run(Cmd: ARGV)
exit status_code
