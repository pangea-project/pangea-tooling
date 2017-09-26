#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'fileutils'
require 'tty/command'

require_relative '../lib/adt/summary'
require_relative '../lib/adt/junit/summary'
require_relative '../lib/nci'
require_relative 'lib/setup_repo'

JOB_NAME = File.read('job_name').strip
if NCI.experimental_skip_qa.any? { |x| JOB_NAME.include?(x) }
  warn "Job #{JOB_NAME} marked to skip QA. Not running autopkgtest (adt)."
  exit 0
end

if JOB_NAME.include?('_armhf')
  warn 'Not running adt on the armhf architecture'
  exit 0
end

NCI.setup_repo!

TESTS_DIR = 'build/debian/tests'.freeze
JUNIT_FILE = 'adt-junit.xml'.freeze

unless Dir.exist?(TESTS_DIR)
  puts "Package doesn't appear to be autopkgtested. Skipping."
  exit
end

if Dir.glob("#{TESTS_DIR}/*").any? { |x| File.read(x).include?('Xephyr') }
  suite = JenkinsJunitBuilder::Suite.new
  suite.name = 'autopkgtest'
  suite.package = 'autopkgtest'
  suite.add_case(JenkinsJunitBuilder::Case.new.tap do |c|
    c.name = 'TestsPresent'
    c.time = 0
    c.classname = 'TestsPresent'
    c.result = JenkinsJunitBuilder::Case::RESULT_PASSED
    c.system_out.message = 'debian/tests/ is present'
  end)
  suite.add_case(JenkinsJunitBuilder::Case.new.tap do |c|
    c.name = 'XephyrUsage'
    c.time = 0
    c.classname = 'XephyrUsage'
    c.result = JenkinsJunitBuilder::Case::RESULT_SKIPPED
    c.system_out.message = 'Tests using xephyr; would get stuck.'
  end)
  suite.build_report
  File.write(JUNIT_FILE, suite.build_report)
  exit
end

# Gecos is additonal information that would be prompted
system('adduser',
       '--disabled-password',
       '--gecos', '',
       'adt')

Apt.install(%w[autopkgtest])

FileUtils.rm_r('adt-output') if File.exist?('adt-output')

Dir.chdir('/') do
  next unless Process.uid.zero?
  FileUtils.cp("#{__dir__}/adt-helpers/mktemp", '/usr/sbin/mktemp',
               verbose: true)
  FileUtils.chmod(0o0755, '/usr/sbin/mktemp')
  system("patch -p0 < #{__dir__}/adt-helpers/adt-run.diff") || raise

  # Override ctest to inject an argument forcing the timeout per test at 5m.
  file = '/usr/bin/ctest'
  next if File.exist?("#{file}.distrib") # Already diverted
  system('dpkg-divert', '--local', '--rename', '--add', file) || raise
  File.open(file.to_s, File::RDWR | File::CREAT, 0o755) do |f|
    f.write(<<-EOF)
#!/bin/sh
#{file}.distrib --timeout #{5 * 60} "$@"
EOF
  end
end

args = []
Dir.glob('*.deb').each { |x| args << '--binary' << x }
args << '--built-tree' << "#{Dir.pwd}/build"
args << '--output-dir' << 'adt-output'
args << '--user=adt'
args << "--timeout-test=#{30 * 60}"
# Try to force Qt to time out on test functions after 5 minutes.
# This should be the default but doesn't seem to actually work for some reason.
args << "--env=QTEST_FUNCTION_TIMEOUT=#{5 * 60 * 1000}"
# Disable KIO using kdeinit and starting http cleanup
args << '--env=KDE_FORK_SLAVES=yes'
args << '--env=KIO_DISABLE_CACHE_CLEANER=yes'
args << '---' << 'null'
begin
  TTY::Command.new(uuid: false).run('adt-run', *args, timeout: 30 * 60)
rescue TTY::Command::ExitError => error
  puts error.message
end


summary = ADT::Summary.from_file('adt-output/summary')
unit = ADT::JUnit::Summary.new(summary)
File.write(JUNIT_FILE, unit.to_xml)

FileUtils.rm_rf('adt-output/binaries', verbose: true)
# Agressively compress the output for archiving. We want to save as much
# space as possible, since we have lots of these.
system('tar -cf adt-output.tar adt-output')
system('xz -9 adt-output.tar')
