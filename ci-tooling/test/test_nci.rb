# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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
require_relative '../lib/nci'

# Test NCI extensions on top of xci
class XCITest < TestCase
  def test_experimental_skip_qa
    skip = NCI.experimental_skip_qa
    assert_false(skip.empty?)
    assert(skip.is_a?(Array))
  end

  def test_only_adt
    only = NCI.only_adt
    assert_false(only.empty?)
    assert(only.is_a?(Array))
  end

  def test_future_series
    # Can be nil, otherwise it must be part of the array.
    return if NCI.future_series.nil?
    assert_include NCI.series.keys, NCI.future_series
  end

  def test_current_series
    assert_include NCI.series.keys, NCI.current_series
  end
end
