#!/usr/bin/env ruby

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
JOB_NAME = ENV.fetch('JOB_NAME')

c = Containment.new(JOB_NAME, image: "jenkins/#{DIST}_#{TYPE}")
status_code = c.run(Cmd: ARGV)
exit status_code
