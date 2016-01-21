#!/usr/bin/env ruby

require_relative '../lib/apt'
require 'fileutils'

fail 'No live-config found!' unless File.exist?('live-config')

Apt.update
Apt.install(%w(ubuntu-defaults-builder))

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
