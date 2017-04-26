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
require_relative '../nci/lint/cmake_dep_verify/package'

require 'mocha/test_unit'

module CMakeDepVerify
  class PackageTest < TestCase
    def setup
      # Reset caching.
      Apt::Repository.send(:reset)
      # Disable automatic update
      Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
      # Make sure $? is fine before we start!
      reset_child_status!
      # Disable all system invocation.
      Object.any_instance.expects(:`).never
      Object.any_instance.expects(:system).never

      Package.dry_run = true
    end

    def test_test_success
      Object
        .any_instance
        .stubs(:system)
        .with('apt-get') { |cmd| cmd == 'apt-get' }
        .returns(true)

      DPKG.expects(:list).with('libkf5coreaddons-dev').returns(%w(
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsTargets.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsMacros.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsTargets-debian.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsConfigVersion.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsConfig.cmake)
      )

      pkg = Package.new('libkf5coreaddons-dev', '1')
      res = pkg.test
      assert_equal(1, res.size)
      assert_equal('KF5CoreAddons', res.keys[0])
      res = res.values[0]
      assert_equal(true, res.success?)
      assert_equal('', res.out)
      assert_equal('', res.err)
    end

    def test_test_fail
      Object
        .any_instance
        .stubs(:system)
        .with('apt-get') { |cmd| cmd == 'apt-get' }
        .returns(true)

      DPKG.expects(:list).with('libkf5coreaddons-dev').returns(%w(
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsTargets.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsMacros.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsTargets-debian.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsConfigVersion.cmake
        /usr/lib/x86_64-linux-gnu/cmake/KF5CoreAddons/KF5CoreAddonsConfig.cmake)
      )

      result = mock('result').responds_like_instance_of(TTY::Command::Result)
      result.stubs(:success?).returns(false)
      result.stubs(:out).returns('output')
      result.stubs(:err).returns('error')
      TTY::Command.any_instance.stubs(:run).returns(result)

      pkg = Package.new('libkf5coreaddons-dev', '1')
      res = pkg.test
      assert_equal(1, res.size)
      assert_equal('KF5CoreAddons', res.keys[0])
      res = res.values[0]
      assert_equal(false, res.success?)
      assert_equal('output', res.out)
      assert_equal('error', res.err)
    end
  end
end
