#!/usr/bin/env ruby
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

require 'bundler/setup'
require 'ci/reporter/rake/test_unit_loader'
require 'logger'
require 'logger/colors'
require 'open-uri'
require 'test/unit'

require_relative '../lib/lint/control'
require_relative '../lib/lint/log'
require_relative '../lib/lint/merge_marker'
require_relative '../lib/lint/result'
require_relative '../lib/lint/series'
require_relative '../lib/lint/symbols'

ENV['CI_REPORTS'] = "#{Dir.pwd}/reports".freeze

# BUILD_URL = ENV.fetch('BUILD_URL')
BUILD_URL = File.read('build_url')
LOG_URL = "#{BUILD_URL}/consoleText".freeze

module Lint
  class TestCase < Test::Unit::TestCase
    def assert_result(result)
      assert(result.valid, "Lint result not valid ::\n #{result}")
      notify(result.warnings.join("\n")) unless result.warnings.empty?
      notify(result.informations.join("\n")) unless result.informations.empty?
      # Flunking fails the test entirely, so this needs to be at the very end!
      flunk(result.errors.join("\n")) unless result.errors.empty?
    end
  end

  class TestLog < TestCase
    def initialize(*args)
      super
      @log_orig = open(LOG_URL).read
    end

    def setup
      @log = @log_orig.dup
    end

    def test_cmake
      assert_result Log::CMake.new.lint(@log)
    end

    def test_lintian
      assert_result Log::Lintian.new.lint(@log)
    end

    def test_list_missing
      assert_result Log::ListMissing.new.lint(@log)
    end
  end

  class TestPackaging < TestCase
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

    def test_merge_markers
      assert_result MergeMarker.new(@dir).lint
    end
  end
end
