#!/usr/bin/env ruby

require_relative '../lib/ci/build_binary'
require_relative '../lib/apt'


dist = ENV.fetch('DIST')
repos = %w(frameworks plasma odroid netrunner)
repos += %w(qt5) if dist == 'stable'

# FIXME: Fix repo addition
repos.each do |repo|
  Apt::Repository.add("deb http://dci.ds9.pub:8080/#{repo}/ #{dist} main")
end

Apt::Key.add("#{__dir__}/dci_apt.key")
Apt.update

builder = CI::PackageBuilder.new
builder.build
