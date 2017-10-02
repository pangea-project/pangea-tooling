#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/apt'
require 'fileutils'

# Add the ppa from Ubuntu's train service
Apt.update
Apt.install(%w[live-build])

ec = 0

begin
  FileUtils.mkdir_p 'result'
  Dir.chdir('rootfs-builder') do
    system('ls -lah')
    ec = system("./build.sh #{ARGV[0]}")
    FileUtils.mv(Dir.glob('halium*'), '../result', verbose: true)
  end
ensure
  Dir.chdir('rootfs-builder') do
    system('lb clean --purge')
  end
  system('chown -Rv jenkins:jenkins .')
end

exit ec
