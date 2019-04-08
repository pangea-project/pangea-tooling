# frozen_string_literal: true
#
# Copyright (C) 2018-2019 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/lint/log/dh_missing'
require_relative 'lib/testcase'

# Test lint lintian
class LintDHMissingTest < TestCase
  def test_valid
    r = Lint::Log::DHMissing.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(0, r.warnings.size)
    assert_equal(6, r.errors.size)
  end

  def test_no_dh_missing
    r = Lint::Log::DHMissing.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(0, r.warnings.size)
    assert_equal(0, r.errors.size)
  end

  def test_bad_log
    r = Lint::Log::DHMissing.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(0, r.warnings.size)
    assert_equal(0, r.errors.size)
  end

  def test_indented_dh_output
    # For unknown reasons sometimes the dh output can be indented. Make sure
    # it still parses correctly.
    r = Lint::Log::DHMissing.new.lint(File.read(data))
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(0, r.warnings.size)
    assert_equal(1, r.errors.size)
  end
end
