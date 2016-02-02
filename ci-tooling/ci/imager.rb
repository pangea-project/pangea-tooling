#!/usr/bin/env ruby

require_relative '../lib/apt'
require_relative '../lib/retry'
require 'fileutils'

fail 'No live-config found!' unless File.exist?('live-config')

Retry.retry_it(times: 5) do
  fail 'Apt update failed' unless Apt.update
  fail 'Apt upgrade failed' unless Apt.dist_upgrade
  fail 'Apt install failed' unless Apt.install(%w(live-build live-images qemu-user-static))
end

begin
  FileUtils.mkdir_p 'result'
  Dir.chdir('live-config') do
    system('make clean')
    system('./configure')
    fail unless system('make')
    FileUtils.mv(Dir.glob('live*'), '../result', verbose: true)
    FileUtils.mv(Dir.glob('logfile*'), '../result', verbose: true)
  end
ensure
  Dir.chdir('live-config') do
    system('make clean')
  end
end
