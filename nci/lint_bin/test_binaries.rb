# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../../lib/lint/lintian'
require_relative '../lib/lint/result_test'

module Lint
  # Test result data
  class TestBinaries < ResultTest
    def setup
      # NB: test-unit runs each test in its own instance, this means we
      # need to use a class variable as otherwise the cache wouldn't
      # persiste across test_ invocations :S
      @@result ||= Lintian.new('result').lint
    end

    def test_warnings
      assert_warnings(@@result)
    end

    def test_informations
      assert_informations(@@result)
    end

    def test_errors
      assert_errors(@@result)
    end
  end
end
