#!/usr/bin/env ruby

require_relative 'lxc'

# At peak we have severe load, so better use a sizable timeout for lxc startup.
TIMEOUT = 120
TOOLING_PATH = "#{ENV['HOME']}/tooling"

ELEVATE = ENV['ELEVATE']
DIST = ENV['DIST']
TYPE = ENV['TYPE']
JOB_NAME = ENV['JOB_NAME']

unless DIST && !DIST.empty? && TYPE && !TYPE.empty? && JOB_NAME && !JOB_NAME.empty?
  fail 'Not all env variables set! ABORT!'
end

at_exit do
  # TODO: New Harness created here, it's a bit naughty
  LXC::Harness.new(JOB_NAME).cleanup
end

LXC.elevate = ELEVATE && !ELEVATE.empty?

harness = LXC::Harness.new(JOB_NAME, "#{DIST}_#{TYPE}")
harness.cleanup
harness.setup
fail 'Failed to run command' unless harness.run(ARGV.join(' '))
harness.cleanup
