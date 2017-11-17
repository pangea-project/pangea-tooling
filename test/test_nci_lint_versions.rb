# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../nci/lint/versions'

require 'mocha/test_unit'

module NCI
  class VersionsTestTest < TestCase
    # Dud
    CommandResult = Struct.new(:failure?, :out, :err) do
      def initialize(*)
        super
        self.out ||= ''
        self.err ||= ''
      end

      def to_ary
        [out, err]
      end
    end

    def setup
      VersionsTest.reset!
    end

    def test_file_lister
      FileUtils.cp_r("#{datadir}/.", '.')

      TTY::Command
        .any_instance
        .stubs(:run!)
        .with('apt show foo')
        .returns(CommandResult.new(false, <<~STDOUT))
Package: foo
Version: 0.9
Priority: extra
      STDOUT

      TTY::Command
        .any_instance
        .stubs(:run!)
        .with('apt show bar')
        .returns(CommandResult.new(false, <<~STDOUT))
Package: bar
Version: 1.9
Priority: extra
      STDOUT

      VersionsTest.lister = DirPackageLister.new(Dir.pwd)
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
      linter.send('test_bar_2.0')
    end

    def test_file_lister_bad_version
      FileUtils.cp_r("#{datadir}/.", '.')

      TTY::Command
        .any_instance
        .stubs(:run!)
        .with('apt show foo')
        .returns(CommandResult.new(false, <<~STDOUT))
Package: foo
Version: 1.1
Priority: extra
      STDOUT

      VersionsTest.lister = DirPackageLister.new(Dir.pwd)
      linter = VersionsTest.new
      assert_raises PackageVersionCheck::VersionNotGreaterError do
        linter.send('test_foo_1.0')
      end
    end

    def test_repo
      repo = mock('repo')
      # Simple aptly package string
      repo.expects(:packages).returns(['Pamd64 foo 0.9 abc'])

      TTY::Command
        .any_instance
        .stubs(:run!)
        .with('apt show foo')
        .returns(CommandResult.new(false, <<~STDOUT))
Package: foo
Version: 0.9
Priority: extra
      STDOUT

      VersionsTest.lister = RepoPackageLister.new(repo)
      linter = VersionsTest.new
      assert_raises PackageVersionCheck::VersionNotGreaterError do
        linter.send('test_foo_0.9')
      end
    end

    def test_default_repo
      # Constructs an env derived default repo name.
      ENV['TYPE'] = 'xx'
      ENV['DIST'] = 'yy'
      Aptly::Repository.expects(:get).with('xx_yy')

      RepoPackageLister.new
    end

    def test_pure_virtual
      # When showing a pure virtual it comes back 0 but has no valid
      # version.
      FileUtils.cp_r("#{datadir}/.", '.')

      TTY::Command
        .any_instance
        .stubs(:run!)
        .with('apt show foo')
        .returns(CommandResult.new(false, '', <<~STDERR))
N: Can't select versions from package 'foo' as it is purely virtual
N: No packages found
      STDERR

      VersionsTest.lister = DirPackageLister.new(Dir.pwd)
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
    end
  end
end
