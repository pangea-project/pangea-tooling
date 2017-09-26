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

ENV['CI_REPORTS'] = "#{Dir.pwd}/reports"
# FIXME: should use env not the marker file
# BUILD_URL = ENV.fetch('BUILD_URL')
BUILD_URL = File.read('build_url').strip
ENV['LOG_URL'] = "#{BUILD_URL}/consoleText"

Dir.glob(File.expand_path('lint_bin/test_*.rb', __dir__)).each do |file|
  require file
end
