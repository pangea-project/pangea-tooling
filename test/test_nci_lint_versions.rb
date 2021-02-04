# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lint/versions'

require 'mocha/test_unit'

module NCI
  class VersionsTestTest < TestCase
    Package = Struct.new(:name, :version)

    def setup
      VersionsTest.reset!
    end

    def standard_ours
      [Package.new('foo', '1.0'), Package.new('bar', '2.0')]
    end

    def test_file_lister
      VersionsTest.init(ours: standard_ours,
                        theirs: [Package.new('foo', '0.5')])
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
      linter.send('test_bar_2.0')
    end

    def test_file_lister_bad_version
      VersionsTest.init(ours: standard_ours,
                        theirs: [Package.new('foo', '1.1')])
      linter = VersionsTest.new
      assert_raises PackageVersionCheck::VersionNotGreaterError do
        linter.send('test_foo_1.0')
      end
    end

    def test_pure_virtual
      # When showing a pure virtual it comes back 0 but has no valid
      # data. THIS ONLY HAPPENS WHEN CALLED FROM OUTSIDE A TERMINAL!
      # On a terminal it tells you that it is pure virtual. I hate apt with
      # all my life.
      VersionsTest.init(ours: standard_ours,
                        theirs: [Package.new('foo', nil)])
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
    end

    def test_already_debian_version
      # When showing a pure virtual it comes back 0 but has no valid
      # data. THIS ONLY HAPPENS WHEN CALLED FROM OUTSIDE A TERMINAL!
      # On a terminal it tells you that it is pure virtual. I hate apt with
      # all my life.
      VersionsTest.init(ours: standard_ours,
                        theirs: [Package.new('foo',
                                             Debian::Version.new('0.5'))])
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
    end
  end
end
