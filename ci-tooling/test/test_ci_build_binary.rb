# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2015 Rohan Garg <rohan@kde.org>
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
  class BuildBinaryTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg-source dpkg dh)

    def refute_bin_only(builder)
      refute(builder.instance_variable_get(:@bin_only))
    end

    def assert_bin_only(builder)
      assert(builder.instance_variable_get(:@bin_only))
    end

    def test_build_package
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)

      builder = PackageBuilder.new
      builder.build_package

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('*.deb'))
      assert_path_exist('hello_2.10_amd64.changes')
      changes = Debian::Changes.new('hello_2.10_amd64.changes')
      changes.parse!
      assert_equal(['hello_2.10_amd64.deb'],
                   changes.fields['files'].map(&:name))

      refute_bin_only(builder)
    end

    def test_dep_resolve_bin_only
      Object.any_instance.expects(:system).never

      File.expects(:executable?)
          .with(PackageBuilder::DependencyResolver::RESOLVER_BIN)
          .returns(true)

      Object.any_instance
            .expects(:system)
            .with({'DEBIAN_FRONTEND' => 'noninteractive'},
                  '/usr/lib/pbuilder/pbuilder-satisfydepends-classic',
                  '--binary-arch',
                  '--control', "#{Dir.pwd}/debian/control")
            .returns(true)

      PackageBuilder::DependencyResolver.resolve(Dir.pwd, bin_only: true)
    end

    def test_build_bin_only
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      Dir.chdir('build') { system('dpkg-buildpackage -S -us -uc') }

      PackageBuilder::DependencyResolver.expects(:resolve)
                                        .with('build')
                                        .raises(RuntimeError.new)
      PackageBuilder::DependencyResolver.expects(:resolve)
                                        .with('build', bin_only: true)
                                        .returns(true)

      builder = PackageBuilder.new
      builder.build

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('*.deb'))
      assert_path_exist('test-build-bin-only_2.10_amd64.changes')
      changes = Debian::Changes.new('test-build-bin-only_2.10_amd64.changes')
      changes.parse!
      assert_equal(['test-build-bin-only_2.10_amd64.deb'],
                   changes.fields['files'].map(&:name))

      assert_bin_only(builder)
    end
  end
end
