#!/usr/bin/env ruby

ENV['LC_ALL'] = 'C.UTF-8'
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ENV['DEBFULLNAME'] = 'Debian CI'
ENV['DEBEMAIL'] = 'null@debian.org'

require 'date'
require 'fileutils'
require_relative 'lib/debian/changelog'

if Process.uid == '0'
  exit 1 unless system('apt-get update')
  exit 1 unless system('apt-get install -y lsb-release')
end

require_relative "dci/#{ARGV[0]}"
