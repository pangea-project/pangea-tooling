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

Dir.chdir('result') do
  @images = Dir.glob('*.{iso,tar}*')
  raise 'Build failed!' unless @images.size == 1

  # Symlink in the result folder so that S3 gets a generic entry pointing to the latest tar or ISO
  FileUtils.ln_s(@images[0], 'latest.iso', verbose: true) if @images[0].end_with? '.iso'
  FileUtils.ln_s(@images[0], 'latest.tar', verbose: true) if @images[0].end_with? '.tar'
end
