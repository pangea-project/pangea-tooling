# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/lint/log/lintian'
require_relative 'lib/testcase'

# Test lint lintian
class LintLintianTest < TestCase
  def test_lint
    r = Lint::Log::Lintian.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(2, r.informations.size)
    assert_equal(4, r.warnings.size)
    assert_equal(0, r.errors.size)
  end

  def test_invalid
    r = Lint::Log::Lintian.new.lint(File.read(data))
    assert(!r.valid)
  end
end
