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

require_relative '../../lib/lint/control'
require_relative '../../lib/lint/merge_marker'
require_relative '../../lib/lint/series'
require_relative '../../lib/lint/symbols'
require_relative '../lib/lint/result_test'

module Lint
  # Test static files.
  class TestPackaging < ResultTest
    def setup
      @dir = 'build'.freeze
    end

    def test_control
      assert_result Control.new(@dir).lint
    end

    def test_series
      assert_result Series.new(@dir).lint
    end

    def test_symbols
      assert_result Symbols.new(@dir).lint
    end

    # FIXME: merge_marker disabled as we run after build and after build
    #   debian/ contains debian/tmp and others with binary artifacts etcpp..
    # def test_merge_markers
    #   assert_result MergeMarker.new("#{@dir}/debian").lint
    # end
  end
end
