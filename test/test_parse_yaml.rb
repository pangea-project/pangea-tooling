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

require 'test/unit'
require 'yaml'

class ParseYAMLTest < Test::Unit::TestCase
  def test_syntax
    Dir.chdir(File.dirname(__dir__)) # one above

    Dir.glob('**/**/*.{yml,yaml}').each do |file|
      next if file.include?('git/') || file.include?('launchpad/') || file.include?('test/')
      next unless File.file?(file)
      # assert_nothing_raised is a bit stupid, it eats most useful information
      # from the exception, so to debug this best run without the assert to
      # get the additional information.
      assert_nothing_raised("Not a valid YAML file: #{file}") do
        YAML.load(File.read(file))
      end
    end
  end
end
