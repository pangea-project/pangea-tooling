#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/docker/cleanup'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

Docker::Cleanup.containers
Docker::Cleanup.images
Docker::Cleanup.remove_image(Docker::Image.get('debianci/amd64:next'))
Docker::Cleanup.remove_image(Docker::Image.get('pangea/debian:next'))
