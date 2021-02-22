# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/lint/lintian'
require_relative 'lib/testcase'

# Test lint lintian
class LintLintianTest < TestCase
  def setup
    Dir.mkdir('result')
    # Linter checks for a changes file to run against
    FileUtils.touch('result/foo.changes')
  end

  def test_lint
    cmd = TTY::Command.new
    cmd
      .expects(:run!)
      .with { |*args| args[0] == 'lintian' && args.any? { |x| x.end_with?('foo.changes') } }
      .returns(TTY::Command::Result.new(1, File.read(data), ''))
    # Exit code 0 or 1 shouldn't make a diff. Lintian will exit 1 if there
    # are problems, 0 when not - we do run parsing eitherway

    r = Lint::Lintian.new('result', cmd: cmd).lint
    assert(r.valid)
    assert_equal(2, r.informations.size)
    assert_equal(4, r.warnings.size)
    assert_equal(0, r.errors.size)
  end

  def test_lib_error_promotion
    # soname mismatches on library packages are considered errors,
    # others are mere warnings.
    # this helps guard against wrong packaging leading to ABI issues
    cmd = TTY::Command.new
    cmd
      .expects(:run!)
      .with { |*args| args[0] == 'lintian' && args.any? { |x| x.end_with?('foo.changes') } }
      .returns(TTY::Command::Result.new(0, <<~OUTPUT, ''))
W: libkcolorpicker0: package-name-doesnt-match-sonames libkColorPicker0.1.4
W: meow: package-name-doesnt-match-sonames libmeowsa
      OUTPUT
    # Exit code 0 or 1 shouldn't make a diff. Lintian will exit 1 if there
    # are problems, 0 when not - we do run parsing eitherway

    r = Lint::Lintian.new('result', cmd: cmd).lint
    assert(r.valid)
    assert_equal(0, r.informations.size)
    assert_equal(1, r.warnings.size)
    assert_equal(1, r.errors.size)
  end
end
