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

require_relative '../lib/adt/summary'
require_relative '../lib/adt/junit/summary'
require_relative 'lib/setup_repo'

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

Apt.install(%w(autopkgtest))

FileUtils.rm_r('adt-output') if File.exist?('adt-output')

args = []
Dir.glob('*.deb').each do |x|
  args << '--binary' << x
end
# args << '--unbuilt-tree' << 'krunner-5.18.0+git20160314.0121+15.10'
args << '--built-tree' << "#{Dir.pwd}/build"
args << '--output-dir' << 'adt-output'
args << '--user=adt'
args << '---' << 'null'
puts "adt-run #{args.join(' ')}"
system('adt-run', *args)

summary = ADT::Summary.from_file('adt-output/summary')
unit = ADT::JUnit::Summary.new(summary)
File.write(JUNIT_FILE, unit.to_xml)

# Agressively compress the output for archiving. We want to save as much
# space as possible, since we have lots of these.
system('tar -cf adt-output.tar adt-output')
system('xz -9 adt-output.tar')
