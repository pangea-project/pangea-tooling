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
      assert_equal('linux-any', rel.architectures)
      assert_equal('a (<< 1.0) [linux-any] <multi>', rel.to_s)
    end

    def test_ord_deps
      rel = Relationship.new('foo [!i386] | bar [!amd64]')
      assert_equal('foo', rel.name)
      assert_equal('bar', rel.next.name)
      assert_equal('!i386', rel.architectures)
      assert_equal('foo [!i386] | bar [!amd64]', rel.to_s)
    end

    def test_compare
      a = Relationship.new('a')
      b = Relationship.new('b')
      suba = Relationship.new('${a}')
      subb = Relationship.new('${b}')
      assert((a <=> b) == -1)
      assert((a <=> a) == 0)
      assert((b <=> a) == 1)
      assert((suba <=> a) == -1)
      assert((suba <=> suba) == 0)
      assert((suba <=> subb) == -1)
    end
  end
end
