#!/usr/bin/env ruby

require_relative '../lib/apt'
require_relative '../lib/retry'
require_relative '../lib/ci/lb_runner'
require_relative '../dci/lib/setup_repo'

raise 'No live-config found!' unless File.exist?('live-config')

DCI.setup_repo!

Retry.retry_it(times: 5) do
  raise 'Apt update failed' unless Apt.update
  raise 'Apt upgrade failed' unless Apt.dist_upgrade
  raise 'Apt install failed' unless Apt.install(%w(live-build live-images))
end

@lb = LiveBuildRunner.new('live-config')
@lb.configure!
@lb.build!
