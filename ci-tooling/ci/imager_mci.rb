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
  system('ls -lah')
  ec = system('./build.sh')
  FileUtils.mv(Dir.glob('halium*'), '../result', verbose: true)
ensure
  Dir.chdir('rootfs-builder') do
    system('lb clean --purge')
  end
end

exit ec
