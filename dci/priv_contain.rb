#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)
binds = [
  "#{TOOLING_PATH}:#{TOOLING_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}",
  "/dev:/dev"
]

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.
DIST_RELEASE = ENV.fetch('DIST_RELEASE')
BUILD_TAG = ENV.fetch('BUILD_TAG')

# Whitelist a bunch of Jenkins variables for consumption inside the container.
whitelist = %w[BUILD_CAUSE ROOT_BUILD_CAUSE RUN_DISPLAY_URL JOB_NAME
               NODE_NAME NODE_LABELS DIST_RELEASE
               PANGEA_PROVISION_AUTOINST
               DH_VERBOSE]
whitelist += (ENV['DOCKER_ENV_WHITELIST'] || '').split(':')
ENV['DOCKER_ENV_WHITELIST'] = whitelist.join(':')

c = CI::Containment.new(BUILD_TAG,
                        image: CI::PangeaImage.new(:debian, DIST_RELEASE),
                        privileged: true,
                        no_exit_handlers: false,
                        binds: binds)
status_code = c.run(Cmd: ARGV)
exit status_code
