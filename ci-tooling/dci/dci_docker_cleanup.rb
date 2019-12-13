#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative '../../lib/docker/cleanup'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

Docker::Cleanup.containers
Docker::Cleanup.images
log = Docker::Cleanup.log
%w[debianci/amd64:next pangea/debian:next debianci/amd64:2001 pangea/debian:2001].each do |name|
  begin
    Docker::Cleanup.remove_image(Docker::Image.get(name))
  rescue => e
    log.info "Failed to get #{name} :: #{e}"
    next
  end
end
