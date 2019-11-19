#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require_relative '../lib/apt'
require_relative '../lib/retry'
require_relative '../lib/ci/lb_runner'
require_relative '../dci/lib/setup_repo'

raise 'No live-config found!' unless File.exist?('live-config')
workspace = ENV['WORKSPACE']

DCI.setup_repo!

Retry.retry_it(times: 5) do
  raise 'Apt update failed' unless Apt.update
  raise 'Apt upgrade failed' unless Apt.dist_upgrade
  #Should be on base image now.
  raise 'Apt install failed' unless Apt.install(%w[live-build parted initramfs-tools])
end

@lb = LiveBuildRunner.new('live-config')
@lb.configure!
@lb.build!

FileUtils.mv('result', "#{workspace}", verbose: true)
raise 'No result found!' unless File.exist?("#{workspace}/result")
FileUtils.remove_dir('live-config')
