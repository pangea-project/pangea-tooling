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
require_relative 'lib/setup_repo'
require_relative 'lib/adt/summary'
require_relative 'lib/adt/junit/summary'

NCI.setup_repo!

Apt.install(%w(autopkgtest))

FileUtils.rm_r('adt-output') if File.exist?('adt-output')

args = []
Dir.glob('*.deb').each do |x|
  args << '--binary' << x
end
# args << '--unbuilt-tree' << 'krunner-5.18.0+git20160314.0121+15.10'
args << '--built-tree' << "#{Dir.pwd}/build"
args << '--output-dir' << 'adt-output'
args << '---' << 'null'
system('adt-run', *args)

summary = ADT::Summary.from_file('adt-output/summary')
unit = ADT::JUnit::Summary.new(summary)
File.write('adt-junit.xml', unit.to_xml)
