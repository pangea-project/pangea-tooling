#!/usr/bin/env ruby

require_relative '../lib/apt'
require_relative '../lib/retry'
require 'fileutils'

raise 'No live-config found!' unless File.exist?('live-config')

Retry.retry_it(times: 5) do
  raise 'Apt update failed' unless Apt.update
  raise 'Apt upgrade failed' unless Apt.dist_upgrade
  raise 'Apt install failed' unless Apt.install(%w(qemu-user-static
                                                   live-build
                                                   live-images))
end

FileUtils.mkdir_p 'result'
Dir.chdir('live-config') do
  system('make clean')
  system('./configure')
  system('lb build')
  FileUtils.mv(Dir.glob('*.{iso,tar}*'), '../result', verbose: true)
  system('lb clean --purge')
end

raise 'Build failed' if Dir.glob('result/*.{iso,tar}*').empty?
