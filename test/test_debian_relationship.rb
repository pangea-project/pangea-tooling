# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/debian/relationship'
require_relative 'lib/testcase'

# Test debian .dsc
module Debian
  class RelationshipTest < TestCase
    def test_empty
      assert_equal(nil, Relationship.new('').name)
    end

    def test_effectively_emtpy
      assert_equal(nil, Relationship.new('  ').name)
    end

    def test_parse_simple
      rel = Relationship.new('a ')
      assert_equal('a', rel.name)
      assert_equal(nil, rel.operator)
      assert_equal(nil, rel.version)
      assert_equal('a', rel.to_s)
    end

    def test_parse_version
      rel = Relationship.new('a    (  <<   1.0   )   ')
      assert_equal('a', rel.name)
      assert_equal('<<', rel.operator)
      assert_equal('1.0', rel.version)
      assert_equal('a (<< 1.0)', rel.to_s)
    end

    def test_parse_complete
      rel = Relationship.new('a    (  <<   1.0   )   [linux-any ] <   multi>')
      assert_equal('a', rel.name)
      assert_equal('<<', rel.operator)
      assert_equal('1.0', rel.version)
      assert_equal('linux-any', rel.architectures.to_s)
      assert_equal(1, rel.profiles.size)
      assert_equal(1, rel.profiles[0].size)
      assert_equal('multi', rel.profiles[0][0].to_s)
      assert_equal('a (<< 1.0) [linux-any] <multi>', rel.to_s)
    end

    def test_parse_profiles
      rel = Relationship.new('foo <nocheck cross> <nocheck>')
      profiles = rel.profiles
      assert(profiles.is_a?(Array))
      assert_equal(2, profiles.size)
      assert(profiles[0].is_a?(ProfileGroup))
    end

    def test_applicable_profile
      # Also tests various input formats
      rel = Relationship.new('foo <nocheck cross> <nocheck>')
      assert rel.applicable_to_profile?('nocheck')
      refute rel.applicable_to_profile?('bar')
      refute rel.applicable_to_profile?(Profile.new('cross'))
      assert rel.applicable_to_profile?(%w[cross nocheck])
      assert rel.applicable_to_profile?('cross   nocheck')
      assert rel.applicable_to_profile?(ProfileGroup.new(%w[cross nocheck]))
      refute rel.applicable_to_profile?(nil)
    end

    def test_applicable_profile_none
      rel = Relationship.new('foo')
      assert rel.applicable_to_profile?(nil)
      assert rel.applicable_to_profile?('nocheck')
    end

    def test_compare
      a = Relationship.new('a')
      b = Relationship.new('b')
      suba = Relationship.new('${a}')
      subb = Relationship.new('${b}')
      assert((a <=> b) == -1)
      assert((a <=> a).zero?)
      assert((b <=> a) == 1)
      assert((suba <=> a) == -1)
      assert((suba <=> suba).zero?)
      assert((suba <=> subb) == -1)
    end
  end
end
