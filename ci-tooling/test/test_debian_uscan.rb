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

require_relative '../lib/debian/uscan'
require_relative 'lib/testcase'

module Debian
  class UScanTest < TestCase
    def test_dehs_newer_available
      packages = UScan::DEHS.parse_packages(File.read(data))
      assert_equal(2, packages.size)
      assert_equal(UScan::States::NEWER_AVAILABLE, packages[0].status)
      assert_equal(UScan::States::NEWER_AVAILABLE, packages[1].status)
      assert_equal('5.6.0', packages[1].upstream_version)
      assert_equal('http://download.kde.org/stable/plasma/5.6.0/libksysguard-5.6.0.tar.xz', packages[1].upstream_url)
    end

    def test_dehs_up_to_date
      packages = UScan::DEHS.parse_packages(File.read(data))
      assert_equal(2, packages.size)
      assert_equal(UScan::States::DEBIAN_NEWER, packages[0].status)
      assert_equal(UScan::States::UP_TO_DATE, packages[1].status)
    end

    def test_dehs_unmapped_status
      assert_raises Debian::UScan::DEHS::ParseError do
        UScan::DEHS.parse_packages(File.read(data))
      end
    end

    def test_dehs_only_older
      packages = UScan::DEHS.parse_packages(File.read(data))
      assert_equal(2, packages.size)
      assert_equal(UScan::States::OLDER_ONLY, packages[0].status)
      assert_equal(UScan::States::UP_TO_DATE, packages[1].status)
    end
  end
end
