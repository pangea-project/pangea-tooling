#!/usr/bin/env ruby

require 'fileutils'

require_relative 'lib/schroot'

if Process.uid != 0
  warn 'Needs to be run as root'
  exit 1
end

require 'ostruct'
require 'optparse'

options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} [options]"

  opts.on('--arch ARCH', 'Architecture to create chroot for') do |v|
    options.arch = v
  end

  opts.on('--series SERIES', 'Distro series to create chroot for') do |v|
    options.series = v
  end

  opts.on('--stability STABILITY', %w(unstable stable),
          'unstable or stable stability flag') do |v|
    options.stability = v
  end
end.parse!

fail 'Need --arch argument' unless options.arch
fail 'Need --series argument' unless options.series
fail 'Need --stability argument' unless options.stability

Schroot.new(stability: options.stability,
            series: options.series,
            arch: options.arch).create
