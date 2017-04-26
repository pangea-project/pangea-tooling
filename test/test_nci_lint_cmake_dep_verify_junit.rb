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

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../nci/lint/cmake_dep_verify/junit'

require 'mocha/test_unit'

module CMakeDepVerify::JUnit
  class SuiteTest < TestCase
    def test_init
      s = Suite.new('kitteh', {})
      assert_xml_equal('<testsuites><testsuite name="CMakePackages" package="kitteh"/></testsuites>',
                       s.to_xml)
    end

    def test_gold
      fail_result = mock('result')
      fail_result.stubs(:success?).returns(false)
      fail_result.stubs(:out).returns("purr\npurr")
      fail_result.stubs(:err).returns("meow\nmeow")

      success_result = mock('result')
      success_result.stubs(:success?).returns(true)
      success_result.stubs(:out).returns("meow\nmeow") # Flipped from above.
      success_result.stubs(:err).returns("purr\npurr")

      s = Suite.new('kitteh', 'KittehConfig' => fail_result,
                              'HettikConfig' => success_result)
      # File.write(fixture_file('.ref'), s.to_xml)
      assert_xml_equal(File.read(fixture_file('.ref')), s.to_xml)
    end
  end
end
