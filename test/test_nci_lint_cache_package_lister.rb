# frozen_string_literal: true
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lint/cache_package_lister'

require 'mocha/test_unit'

module NCI
  class CachePackageListerTest < TestCase
    def setup
      # Disable all command running for this test - the class is a glorified
      # stdout parser.
      TTY::Command.any_instance.expects(:run).never
    end

    def test_packages
      # This must be correctly indented for test accuracy!
      result = mock('tty-command-result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: 2
  Version table:
     2
       1100 http://archive.neon.kde.org/unstable focal/main amd64 Packages
     0.3
        500 http://at.archive.ubuntu.com/ubuntu focal/universe amd64 Packages
bar:
  Installed: (none)
  Candidate: 1
  Version table:
     1 1100
       1100 http://archive.neon.kde.org/unstable focal/main amd64 Packages
     0.5 500
        500 http://at.archive.ubuntu.com/ubuntu focal/universe amd64 Packages
      OUT

      TTY::Command
        .any_instance.expects(:run)
        .with('apt-cache', 'policy', 'foo', 'bar')
        .returns(result)

      pkgs = CachePackageLister.new(filter_select: %w[foo bar]).packages
      assert_equal(2, pkgs.size)
      assert_equal(%w[foo bar].sort, pkgs.map(&:name).sort)
      assert_equal(%w[1 2].sort, pkgs.map(&:version).map(&:to_s).sort)
    end

    def test_packages_filter
      # This must be correctly indented for test accuracy!
      result = mock('tty-command-result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: 1
  Version table:
     1 1100
       1100 http://archive.neon.kde.org/unstable focal/main amd64 Packages
     0.5 500
        500 http://at.archive.ubuntu.com/ubuntu focal/universe amd64 Packages
      OUT

      TTY::Command
        .any_instance.expects(:run)
        .with('apt-cache', 'policy', 'foo')
        .returns(result)

      pkgs = CachePackageLister.new(filter_select: %w[foo]).packages
      assert_equal(1, pkgs.size)
      assert_equal(%w[foo].sort, pkgs.map(&:name).sort)
      assert_equal(%w[1].sort, pkgs.map(&:version).map(&:to_s).sort)
    end

    def test_pure_virtual
      # This must be correctly indented for test accuracy!
      result = mock('tty-command-result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: (none)
  Version table:
      OUT

      TTY::Command
        .any_instance.expects(:run)
        .with('apt-cache', 'policy', 'foo')
        .returns(result)

      pkgs = CachePackageLister.new(filter_select: %w[foo]).packages
      assert_equal(1, pkgs.size)
      assert_equal(%w[foo].sort, pkgs.map(&:name).sort)
      assert_nil(pkgs[0].version)
    end
  end
end
