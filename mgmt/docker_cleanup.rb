#!/usr/bin/env ruby

require_relative '../lib/docker/cleanup'

Excon.defaults[:read_timeout] = 3 * 60 * 60 # 3 hours.

Docker::Cleanup.containers
Docker::Cleanup.images
