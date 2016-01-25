#!/usr/bin/env ruby

require_relative '../lib/ci/build_binary'
require_relative '../lib/apt'

# FIXME: Fix repo addition
%w(frameworks plasma odroid netrunner).each do |repo|
  Apt::Repository.add("deb http://dci.ds9.pub:8080/#{repo}/ unstable main")
end

Apt::Key.add("#{__dir__}/dci_apt.key")
Apt.update

builder = CI::PackageBuilder.new
builder.build
