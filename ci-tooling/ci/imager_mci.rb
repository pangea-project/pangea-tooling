#!/usr/bin/env ruby

require_relative '../lib/apt'
require 'fileutils'

raise 'No live-config found!' unless File.exist?('live-config')

# Add the ppa from Ubuntu's train service
@ppa = 'ppa:ci-train-ppa-service/stable-snapshot'
Apt::Repository.add(@ppa)
Apt.update
Apt.install(%w(livecd-rootfs))

ec = 0

begin
  FileUtils.mkdir_p 'result'
  Dir.chdir('live-config') do
    system('make clean')
    system('./configure')
    ec = system('make')
    FileUtils.mv(Dir.glob('live*'), '../result', verbose: true)
    FileUtils.mv(Dir.glob('logfile*'), '../result', verbose: true)
  end
ensure
  Dir.chdir('live-config') do
    system('make clean')
  end
end

exit ec
