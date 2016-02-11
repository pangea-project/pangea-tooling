#!/usr/bin/env ruby

require_relative '../lib/apt'
require_relative '../lib/retry'
require_relative '../lib/os'
require 'fileutils'

raise 'No live-config found!' unless File.exist?('live-config')

Retry.retry_it(times: 5) do
  raise 'Apt update failed' unless Apt.update
  raise 'Apt upgrade failed' unless Apt.dist_upgrade
  raise 'Apt install failed' unless Apt.install(%w(qemu-user-static
                                                   live-build
                                                   live-images))
end

# Workaround a broken debootstrap on Debian
if OS::ID == 'debian'
  system('wget -P /tmp ftp://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.73~bpo8+1_all.deb')
  system('dpkg -i /tmp/debootstrap_1.0.73~bpo8+1_all.deb')
end

begin
  FileUtils.mkdir_p 'result'
  Dir.chdir('live-config') do
    system('make clean')
    system('./configure')
    raise unless system('make')
    FileUtils.mv(Dir.glob('live*'), '../result', verbose: true)
    FileUtils.mv(Dir.glob('logfile*'), '../result', verbose: true)
  end
ensure
  Dir.chdir('live-config') do
    system('make clean')
  end
end
