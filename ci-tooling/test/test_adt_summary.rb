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

require_relative 'lib/testcase'
require_relative '../lib/adt/summary'

module ADT
  class SummaryTest < TestCase
    def test_pass
      summary = Summary.from_file("#{data}/summary")
      assert_equal(1, summary.entries.size)
      entry = summary.entries[0]
      assert_equal('testsuite', entry.name)
      assert_equal(Summary::Result::PASS, entry.result)
    end

    def test_partial_fail
      summary = Summary.from_file("#{data}/summary")
      assert_equal(2, summary.entries.size)
      entry = summary.entries[0]
      assert_equal('testsuite', entry.name)
      assert_equal(Summary::Result::FAIL, entry.result)
      assert_equal('non-zero exit status 2', entry.detail)
      entry = summary.entries[1]
      assert_equal('acc', entry.name)
      assert_equal(Summary::Result::PASS, entry.result)
    end

    def test_type_fail
      assert_raises RuntimeError do
        Summary.from_file("#{data}/summary")
      end
    end

    def test_skip_all
      # When we encounter * SKIP that means all have been skipped as there are
      # no tests. This is in junit then dropped as uninteresting information.
      summary = Summary.from_file("#{data}/summary")
      assert_equal(1, summary.entries.size)
      entry = summary.entries[0]
      assert_equal('*', entry.name)
      assert_equal(Summary::Result::SKIP, entry.result)
      assert_equal('no tests in this package', entry.detail)
    end
  end
end
