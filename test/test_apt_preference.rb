# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/apt'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test preferences
class PreferenceTest < TestCase
  def setup
    Apt::Preference.config_dir = Dir.pwd
  end

  def teardown
    Apt::Preference.config_dir = nil
  end

  def test_write
    Apt::Preference.new('foo', content: 'bar').write

    assert_path_exist('foo')
    assert_equal('bar', File.read('foo'))
  end

  def test_delete
    File.write('foo', 'xx')

    Apt::Preference.new('foo').delete

    assert_path_not_exist('foo')
  end
end
