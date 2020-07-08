# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

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
      PackageVersionCheck.cmd = stub('VersionsTest.cmd')
                                  .responds_like_instance_of(TTY::Command)
      VersionsTest.reset!
    end

    def test_file_lister
      FileUtils.cp_r("#{datadir}/.", '.')

      result = mock('Result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: 0.9
  Version table:
bar:
  Installed: (none)
  Candidate: 1.9
  Version table:
      OUT
      PackageVersionCheck.cmd
        .expects(:run)
        .with('apt-cache', 'policy', 'bar', 'foo')
        .returns(result)

      VersionsTest.lister = DirPackageLister.new(Dir.pwd)
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
      linter.send('test_bar_2.0')
    end

    def test_file_lister_bad_version
      FileUtils.cp_r("#{datadir}/.", '.')

      result = mock('Result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: 1.1
  Version table:
      OUT
      PackageVersionCheck.cmd
        .expects(:run)
        .with('apt-cache', 'policy', 'bar', 'foo')
        .returns(result)

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

      result = mock('Result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: 1.1
  Version table:
      OUT
      PackageVersionCheck.cmd
        .expects(:run)
        .with('apt-cache', 'policy', 'foo')
        .returns(result)

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
      # data. THIS ONLY HAPPENS WHEN CALLED FROM OUTSIDE A TERMINAL!
      # On a terminal it tells you that it is pure virtual. I hate apt with
      # all my life.
      FileUtils.cp_r("#{datadir}/.", '.')

      result = mock('Result')
      result.stubs(:out).returns(<<-OUT)
foo:
  Installed: (none)
  Candidate: (none)
  Version table:
      OUT
      PackageVersionCheck.cmd
        .expects(:run)
        .with('apt-cache', 'policy', 'bar', 'foo')
        .returns(result)

      VersionsTest.lister = DirPackageLister.new(Dir.pwd)
      linter = VersionsTest.new
      linter.send('test_foo_1.0')
    end

    def test_override_packages
      stub_request(:get, 'https://packaging.neon.kde.org/neon/settings.git/plain/etc/apt/preferences.d/99-focal-overrides?h=Neon/release-lts').
          with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
          to_return(status: 200, body: "Package: aptdaemon\nPin: release o=Ubuntu\nPin-Priority: 1100\n\nPackage: aptdaemon-data\nPin: release o=Ubuntu\nPin-Priority: 1100", headers: {'Content-Type'=> 'text/plain'})

      PackageUpgradeVersionCheck.override_packages
      override_packages = PackageUpgradeVersionCheck.override_packages
      assert_equal(["aptdaemon", "aptdaemon-data"], override_packages)
    end

  end
end
