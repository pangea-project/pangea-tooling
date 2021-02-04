# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/debian/profile'
require_relative 'lib/testcase'

module Debian
  class ProfileTest < TestCase
    def test_matches_negation
      group = ProfileGroup.new('!flup')
      assert(group.matches?(Profile.new('xx')))
    end

    def test_not_matches_negation
      group = ProfileGroup.new('!flup')
      refute(group.matches?(Profile.new('flup')))
    end

    def test_not_matches_single_of_group
      group = ProfileGroup.new(%w[nocheck cross])
      refute(group.matches?(Profile.new('cross')))
    end

    def test_matches_group
      profiles = [ProfileGroup.new(%w[nocheck cross])]
      assert(profiles.any? do |group|
        group.matches?([Profile.new('cross'), Profile.new('nocheck')])
      end)
    end
  end
end
