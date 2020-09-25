#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Enable the apt resolver by default (instead of pbuilder); should be faster!
# NB: This needs to be set before requires, it's evaluated at global scope.
# TODO: make default everywhere. only needs some soft testing in production
ENV['PANGEA_APT_RESOLVER'] = '1'

require_relative 'lib/setup_repo'
require_relative '../lib/ci/build_binary'
require_relative '../lib/nci'
require_relative '../lib/retry'
require_relative '../../lib/pangea_build_type_config'

NCI.setup_repo!

if File.exist?('/ccache')
  require 'mkmf' # for find_exectuable

  Retry.retry_it(times: 4) { Apt.install('ccache') || raise }
  system('ccache', '-z') # reset stats, ignore return value
  ENV['PATH'] = "/usr/lib/ccache:#{ENV.fetch('PATH')}"
  # Debhelper's cmake.pm doesn't resolve from PATH. Bloody crap.
  ENV['CC'] = find_executable('cc')
  ENV['CXX'] = find_executable('c++')
  ENV['CCACHE_DIR'] = '/ccache'
end

# Strip optimization relevant flags from dpkg-buildflags. We'll defer this
# decision to cmake (via our overlay-bin/cmake)
if PangeaBuildTypeConfig.override?
  warn 'Tooling: stripping various dpkg-buildflags'
  flags = %w[CFLAGS CPPFLAGS CXXFLAGS OBJCFLAGS OBJCXXFLAGS OBJCXXFLAGS FFLAGS
             FCFLAGS LDFLAGS]
  flagsconf = flags.collect do |flag|
    <<-FLAGSEGMENT
STRIP #{flag} -g
STRIP #{flag} -O2
STRIP #{flag} -O0
    FLAGSEGMENT
  end.join("\n")
  File.write('/etc/dpkg/buildflags.conf', flagsconf)
end

no_adt = NCI.only_adt.none? { |x| ENV['JOB_NAME']&.include?(x) }
# Hacky: p-f's tests/testengine is only built and installed when
#   BUILD_TESTING is set, fairly weird but I don't know if it is
#   intentional
# - kimap installs kimaptest fakeserver/mockjob
#   https://bugs.kde.org/show_bug.cgi?id=419481
needs_testing = %w[
  plasma-framework
  kimap
]
is_excluded = needs_testing.any? { |x| ENV['JOB_NAME']&.include?(x) }
if no_adt && !is_excluded
  # marker file to tell our cmake overlay to disable test building
  File.write('adt_disabled', '')
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
  require_relative 'lint_bin' if Dir.exist?('build')
end

# For the version check we'll need to unmanagle the preference pin as we rely
# on apt show to give us 'available version' info.
NCI.maybe_teardown_apt_preference
NCI.maybe_teardown_experimental_apt_preference

# Check that our versions are good enough.
unless system('/tooling/nci/lint_versions.rb', '-v')
  warn 'bad versions?'
  warn File.expand_path('../../nci/lint_versions.rb')
  # raise 'Bad version(s)'
end
