# frozen_string_literal: true
#
# Copyright (C) 2017 Rohan Garg <rohan@kde.org>
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

require_relative '../lib/ci/build_binary'
require_relative '../lib/debian/changes'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test ci/build_binary
module CI
  class BuildARMBinaryTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg-source dpkg dh)

    def refute_bin_only(builder)
      refute(builder.instance_variable_get(:@bin_only))
    end

    def assert_bin_only(builder)
      assert(builder.instance_variable_get(:@bin_only))
    end

    def test_arch_arm_source
      FileUtils.cp_r("#{data}/.", Dir.pwd)
      DPKG.stubs(:run)
          .with('dpkg-architecture', ['-qDEB_HOST_ARCH'])
          .returns(['arm64'])

      DPKG.stubs(:run_with_ec)
      .with('dpkg-architecture', %w[-i armhf])
      .returns([[], false])

      DPKG.stubs(:run_with_ec)
      .with('dpkg-architecture', %w[-i arm64])
      .returns([[], true])

      builder = PackageBuilder.new

      builder.expects(:extract)
             .at_least_once
             .returns(true)

      builder.expects(:install_dependencies)
             .at_least_once
             .returns(true)

      builder.expects(:build_package)
             .at_least_once
             .returns(true)

      builder.expects(:copy_binaries)
             .at_least_once
             .returns(true)

      builder.expects(:print_contents)
             .at_least_once
             .returns(true)

      builder.build
    end

    def test_arch_all_on_arm
      FileUtils.cp_r("#{data}/.", Dir.pwd)
      DPKG.stubs(:run)
          .with('dpkg-architecture', ['-qDEB_HOST_ARCH'])
          .returns(['arm64'])

      DPKG.stubs(:run_with_ec)
      .with('dpkg-architecture', %w[-i all])
      .returns([[], false])

      DPKG.stubs(:run_with_ec)
      .with('dpkg-architecture', %w[-i amd64])
      .returns([[], false])

      builder = PackageBuilder.new

      builder.expects(:extract)
             .never

      builder.build
    end

  end
end
