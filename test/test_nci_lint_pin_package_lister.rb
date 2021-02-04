# frozen_string_literal: true
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/lint/pin_package_lister'

require 'mocha/test_unit'

module NCI
  class PinPackageListerTest < TestCase
    def setup
      # This must be correctly indented for test accuracy!
      result = mock('tty-command-result')
      result.stubs(:out).returns(<<-OUT)
Package files:
 1100 http://archive.neon.kde.org/unstable focal/main amd64 Packages
     release o=neon,a=focal,n=focal,l=KDE neon - Unstable Edition,c=main,b=amd64
     origin archive.neon.kde.org
 500 http://at.archive.ubuntu.com/ubuntu focal/main amd64 Packages
     release v=20.04,o=Ubuntu,a=focal,n=focal,l=Ubuntu,c=main,b=amd64
     origin at.archive.ubuntu.com
Pinned packages:
     foo -> 1 with priority 1100
     bar -> 2 with priority 1100
      OUT

      TTY::Command
        .any_instance.expects(:run)
        .with('apt-cache', 'policy')
        .returns(result)
    end

    def test_packages
      pkgs = PinPackageLister.new.packages
      assert_equal(2, pkgs.size)
      assert_equal(%w[foo bar].sort, pkgs.map(&:name).sort)
      assert_equal(%w[1 2].sort, pkgs.map(&:version).map(&:to_s).sort)
    end

    def test_packages_filter
      pkgs = PinPackageLister.new(filter_select: %w[foo]).packages
      assert_equal(1, pkgs.size)
      assert_equal(%w[foo].sort, pkgs.map(&:name).sort)
      assert_equal(%w[1].sort, pkgs.map(&:version).map(&:to_s).sort)
    end

    def test_dupe
      # When wildcarding a pin the pin may apply to multiple versions and all
      # of them will be listed in the output.
      # We currently don't support this and raise!
      #
      # Package: *samba*
      # Pin: release o=Ubuntu
      # Pin-Priority: 1100
      #
      # may produce:
      #      samba-dev -> 2:4.11.6+dfsg-0ubuntu1.6 with priority 1100
      #      samba-dev -> 2:4.11.6+dfsg-0ubuntu1 with priority 1100
      # because one version is from the release repo and the other is from
      # updates repo, but they are both o=Ubuntu!

      # This must be correctly indented for test accuracy!
      result = mock('tty-command-result')
      result.stubs(:out).returns(<<-OUT)
Package files:
 1100 http://archive.neon.kde.org/unstable focal/main amd64 Packages
     release o=neon,a=focal,n=focal,l=KDE neon - Unstable Edition,c=main,b=amd64
     origin archive.neon.kde.org
 500 http://at.archive.ubuntu.com/ubuntu focal/main amd64 Packages
     release v=20.04,o=Ubuntu,a=focal,n=focal,l=Ubuntu,c=main,b=amd64
     origin at.archive.ubuntu.com
Pinned packages:
     foo -> 1 with priority 1100
     foo -> 2 with priority 1100
     bar -> 2 with priority 1100
      OUT

      TTY::Command.any_instance.unstub(:run) # Disable the stub from setup first
      TTY::Command
        .any_instance.expects(:run)
        .with('apt-cache', 'policy')
        .returns(result)

      assert_raises RuntimeError do
        PinPackageLister.new(filter_select: %w[foo]).packages
      end
    end
  end
end
