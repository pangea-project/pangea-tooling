# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/lint/log'
require_relative 'lib/testcase'

# Test lint lintian
class LintLogTest < TestCase
  def data
    File.read(super)
  end

  def test_lint
    rs = Lint::Log.new(data).lint
    infos = 0
    warnings = 0
    errors = 0
    rs.each do |r|
      p r
      assert(r.valid)
      infos += r.informations.size
      warnings += r.warnings.size
      errors += r.errors.size
    end
    assert_equal(0, infos)
    # one cmake package warning
    assert_equal(1, warnings)
    # two list-missing files, one dh_missing
    assert_equal(3, errors)
  end

  def test_invalid
    rs = Lint::Log.new('').lint
    rs.each do |r|
      assert(!r.valid)
    end
  end
end
