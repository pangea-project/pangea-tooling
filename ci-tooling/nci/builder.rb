#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'mkmf' # for find_exectuable

require_relative 'lib/setup_repo'
require_relative '../lib/ci/build_binary'
require_relative '../lib/nci'
require_relative '../lib/retry'

NCI.setup_repo!

if File.exist?('/ccache')
  Retry.retry_it(times: 4) { Apt.install('ccache') || raise }
  system('ccache', '-z') # reset stats, ignore return value
  ENV['PATH'] = "/usr/lib/ccache:#{ENV.fetch('PATH')}"
  # Debhelper's cmake.pm doesn't resolve from PATH. Bloody crap.
  ENV['CC'] = find_executable('cc')
  ENV['CXX'] = find_executable('c++')
  ENV['CCACHE_DIR'] = '/ccache'
end

builder = CI::PackageBuilder.new
builder.build

if File.exist?('/ccache')
  system('ccache', '-s') # print stats, ignore return value
end

if File.exist?('build_url')
  url = File.read('build_url').strip
  if NCI.experimental_skip_qa.any? { |x| url.include?(x) }
    puts "Not linting, #{url} is in exclusion list."
    exit
  end
  # skip the linting if build dir doesn't exist
  # happens in case of Architecture: all packages on armhf for example
  if Dir.exist?('build')
    require_relative 'lint_bin'
  end
end
