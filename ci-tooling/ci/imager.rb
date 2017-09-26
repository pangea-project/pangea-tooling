#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/apt'
require_relative '../lib/retry'
require_relative '../lib/ci/lb_runner'

raise 'No live-config found!' unless File.exist?('live-config')

Retry.retry_it(times: 5) do
  raise 'Apt update failed' unless Apt.update
  raise 'Apt upgrade failed' unless Apt.dist_upgrade
  raise 'Apt install failed' unless Apt.install(%w[live-build live-images])
end

@lb = LiveBuildRunner.new('live-config')
@lb.configure!
@lb.build!
