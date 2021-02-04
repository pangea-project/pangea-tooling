# frozen_string_literal: true
#
# Copyright (C) 2014-2018 Harald Sitter <sitter@kde.org>
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

require_relative 'lib/testcase'

require_relative '../lib/shebang'

class ExecutableTest < TestCase
  BINARY_DIRS = %w[
    .
    bin
    dci
    lib/libexec
    nci
    mgmt
    overlay-bin
    xci
    ci
  ].freeze

  SUFFIXES = %w[.py .rb .sh].freeze

  def test_all_binaries_exectuable
    basedir = File.dirname(File.expand_path(File.dirname(__FILE__)))
    not_executable = []
    BINARY_DIRS.each do |dir|
      SUFFIXES.each do |suffix|
        pattern = File.join(basedir, dir, "*#{suffix}")
        Dir.glob(pattern).each do |file|
          next unless File.exist?(file)
          if File.executable?(file)
            sb = Shebang.new(File.open(file).readline)
            # The trailing space in the msg is so it can be copy pasted,
            # without this it'd end in a fullstop.
            assert(sb.valid, "Invalid shebang #{file} ")
          else
            not_executable << file
          end
        end
      end
    end
    # Use a trailing space to make sure we can copy crap without a terminal
    # fullstop inserted by test-unit.
    assert(not_executable.empty?, "Missing +x on #{not_executable.join("\n")} ")
  end
end
