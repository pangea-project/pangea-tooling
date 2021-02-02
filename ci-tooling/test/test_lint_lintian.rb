# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/lint/lintian'
require_relative 'lib/testcase'

# Test lint lintian
class LintLintianTest < TestCase
  def test_lint
    Dir.mkdir('build')
    # Linter checks for a dsc file first
    FileUtils.touch('foo.dsc')
    Dir.chdir('build') do
      cmd = TTY::Command.new
      cmd.expects(:run).with('dpkg-genchanges', '-O../.lintian.changes')
      cmd
        .expects(:run!)
        .with { |*args| args[0] == 'lintian' }
        .returns(TTY::Command::Result.new(1, File.read(data), ''))
      # Exit code 0 or 1 shouldn't make a diff. Lintian will exit 1 if there
      # are problems, 0 when not - we do run parsing eitherway

      r = Lint::Lintian.new(Dir.pwd, cmd: cmd).lint
      assert(r.valid)
      assert_equal(2, r.informations.size)
      assert_equal(4, r.warnings.size)
      assert_equal(0, r.errors.size)
    end
  end
end
