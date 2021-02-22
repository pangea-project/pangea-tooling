# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>

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
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      # this is intentional!
      assert((a <=> a).zero?)
      assert((b <=> a) == 1)
      assert((suba <=> a) == -1)
      assert((suba <=> suba).zero?)
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands
      assert((suba <=> subb) == -1)
    end
  end
end
