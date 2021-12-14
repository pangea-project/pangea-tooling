#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 36 * 60 * 60 # 36 hours. Because, QtWebEngine.
RELEASE = ENV.fetch('RELEASE')
RELEASE_TYPE = ENV.fetch('RELEASE_TYPE')
SERIES = ENV.fetch('SERIES')
BUILD_TAG = ENV.fetch('BUILD_TAG')

# Whitelist a bunch of Jenkins variables for consumption inside the container.
whitelist = %w[BUILD_CAUSE ROOT_BUILD_CAUSE RUN_DISPLAY_URL JOB_NAME
               NODE_NAME NODE_LABELS DIST BUILD_TAG RELEASE_TYPE RELEASE SERIES
               PANGEA_PROVISION_AUTOINST DH_VERBOSE WORKSPACE]
whitelist += (ENV['DOCKER_ENV_WHITELIST'] || '').split(':')
ENV['DOCKER_ENV_WHITELIST'] = whitelist.join(':')

c = CI::Containment.new(BUILD_TAG, image: CI::PangeaImage.new(:debian, SERIES))
status_code = c.run(Cmd: ARGV)
exit status_code
