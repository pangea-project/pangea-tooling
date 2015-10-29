#!/usr/bin/env ruby

require_relative '../lib/docker/cleanup'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

Docker::Cleanup.images
