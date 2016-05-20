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
require_relative '../lib/aptly-ext/filter'

class AptlyExtFilterTest < TestCase
  def test_init
    packages = [
      'Pall kitteh 999 66f130f348dc4864',
      'Pall kitteh 997 66f130f348dc4864',
      'Pall kitteh 998 66f130f348dc4864',
      'Pamd64 doge 1 66f130f348dc4864',
      'Pamd64 doge 3 66f130f348dc4864',
      'Pamd64 doge 2 66f130f348dc4864'
    ]

    filtered = Aptly::Ext::LatestVersionFilter.filter(packages)
    kitteh = filtered.find_all { |x| x.name == 'kitteh' }
    assert_equal(1, kitteh.size)
    assert_equal('999', kitteh[0].version)
    doge = filtered.find_all { |x| x.name == 'doge' }
    assert_equal(1, doge.size)
    assert_equal('3', doge[0].version)

    filtered = Aptly::Ext::LatestVersionFilter.filter(packages, 2)
    kitteh = filtered.find_all { |x| x.name == 'kitteh' }
    assert_equal(2, kitteh.size)
    kitteh = kitteh.sort_by(&:version)
    assert_equal('998', kitteh[0].version)
    assert_equal('999', kitteh[1].version)
    doge = filtered.find_all { |x| x.name == 'doge' }
    assert_equal(2, doge.size)
    doge = doge.sort_by(&:version)
    assert_equal('2', doge[0].version)
    assert_equal('3', doge[1].version)
  end
end
