#!/usr/bin/env ruby

require 'date'
require 'fileutils'
require_relative 'ci-tooling/lib/debian/changelog'

if Process.uid == '0'
    exit 1 unless system("apt-get update")
    exit 1 unless system("apt-get install -y lsb-release")
end

if ARGV[0] == 'source'
    require_relative 'ci-tooling/dci/source'
elsif ARGV[0] == 'build'
    require_relative 'dci/build'
else
    raise "Need one argument : source or build"
end