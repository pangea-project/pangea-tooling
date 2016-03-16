#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  TOOLING_PATH,
  Dir.pwd
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true)
cmd = ["#{Dir.pwd}/remote-remaster"]
status_code = c.run(Cmd: cmd)
exit status_code
