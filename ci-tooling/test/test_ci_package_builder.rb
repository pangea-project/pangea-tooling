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

require_relative '../lib/ci/package_builder'
require_relative '../lib/debian/changes'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test ci/build_binary
module CI
  class BuildBinaryTest < TestCase
    required_binaries %w(dpkg-buildpackage dpkg-source dpkg dh)

    def setup
      Apt::Repository.send(:reset)
      # Disable automatic update
      Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
      Apt::Repository.stubs(:`).returns('')
    end

    def refute_bin_only(builder)
      refute(builder.instance_variable_get(:@bin_only))
      assert_path_not_exist('reports/build_binary_dependency_resolver.xml')
    end

    def assert_bin_only(builder)
      assert(builder.instance_variable_get(:@bin_only))
      assert_path_exist('reports/build_binary_dependency_resolver.xml')
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
      refute_equal([], changes.fields['files'].map(&:name))

      refute_bin_only(builder)
    end

    # Cross compile for i386
    def test_build_package_cross
      FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)

      arch = 'i386'
      ENV['PANGEA_CROSS'] = arch

      DPKG.stubs(:architecture).returns('amd64')

      # This is a bit stupid because we expect here that this is there is
      # only one cmd instance in the builder, which is true for now but may
      # not always be the case. Might be worth revisiting this if it changes.
      cmd = mock('cmd')
      cmd.expects(:run).with('dpkg', '--add-architecture', arch)
      TTY::Command.expects(:new).returns(cmd)
      Apt::Abstrapt.expects(:system).with do |*args|
        keys = ['install', 'gcc-i686-linux-gnu', 'g++-i686-linux-gnu', 'dpkg-cross']
        overlap = args & keys
        keys == overlap
      end.returns(true)
      Apt::Abstrapt.expects(:system).with do |*args|
        args.include?('update')
      end.returns(true)

      builder = PackageBuilder.new
      builder.build_package

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('*.deb'))
      assert_path_exist('hello_2.10_i386.changes')
      changes = Debian::Changes.new('hello_2.10_i386.changes')
      changes.parse!
      refute_equal([], changes.fields['files'].map(&:name))

      refute_bin_only(builder)
    end

    def test_dep_resolve_bin_only
      Object.any_instance.expects(:system).never

      File.expects(:executable?)
          .with(DependencyResolverPBuilder::RESOLVER_BIN)
          .returns(true)

      Object.any_instance
            .expects(:system)
            .with({'DEBIAN_FRONTEND' => 'noninteractive'},
                  '/usr/lib/pbuilder/pbuilder-satisfydepends',
                  '--binary-arch',
                  '--control', "#{Dir.pwd}/debian/control")
            .returns(true)

      DependencyResolverPBuilder.resolve(Dir.pwd, bin_only: true)
    end

    def test_build_bin_only
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      Dir.chdir('build') { system('dpkg-buildpackage -S -us -uc') }

      # Disable automatic bin only based on architecture. (i.e. amd64 is arch
      # all so it could be bin only by default, but for this test we want
      # to test bin_only detection, so the arch based bin only is getting in
      # the way).
      ENV['PANGEA_ARCH_BIN_ONLY'] = 'false'

      CI::DependencyResolver.expects(:resolve)
                             .with('build')
                             .raises(RuntimeError.new)
      CI::DependencyResolver.expects(:resolve)
                             .with('build', bin_only: true)
                             .returns(true)

      builder = PackageBuilder.new
      builder.build

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('result/*.deb'))
      assert_path_exist('result/test-build-bin-only_2.10_amd64.changes')
      changes = Debian::Changes.new('result/test-build-bin-only_2.10_amd64.changes')
      changes.parse!
      refute_equal([], changes.fields['files'].map(&:name))

      assert_path_exist('result/test-build-bin-only_2.10_amd64.deb.info.txt')
      # Should have plenty of characters (i.e. not be empty and probably contain
      # relevant output)
      assert(File.read('result/test-build-bin-only_2.10_amd64.deb.info.txt').size > 100)

      assert_bin_only(builder)
    end

    def test_build_bin_only_amd64
      # Should NOT bin only
      DPKG.stubs(:run)
        .with('dpkg-architecture', ['-qDEB_HOST_ARCH'])
        .returns(['amd64'])

      builder = PackageBuilder.new
      refute(builder.send(:auto_bin_only, false))
    end

    def test_build_bin_only_arm64
      # Should bin only!
      DPKG.stubs(:run)
        .with('dpkg-architecture', ['-qDEB_HOST_ARCH'])
        .returns(['arm64'])

      builder = PackageBuilder.new
      assert(builder.send(:auto_bin_only, false))
    end

    def test_build_bin_only_bad_value
      # Make sure bad env variables raise
      ENV['PANGEA_ARCH_BIN_ONLY'] = 'foobar'

      builder = PackageBuilder.new
      assert_raises do
        builder.send(:auto_bin_only, false)
      end
    end

    def test_build_bin_only_auto_arch
      # bin-only gets auto enabled for a !arch_all architecture (arm64)

      FileUtils.cp_r("#{data}/.", Dir.pwd)

      Dir.chdir('build') { system('dpkg-buildpackage -S -us -uc') }

      DPKG.stubs(:architecture).returns('arm64')

      CI::DependencyResolver.expects(:resolve)
                            .with('build', bin_only: true)
                            .returns(true)

      builder = PackageBuilder.new
      builder.build

      refute_equal([], Dir.glob('build/*'))
      refute_equal([], Dir.glob('result/*.deb'))
      assert_path_exist('result/test-build-bin-only_2.10_amd64.changes')
      changes = Debian::Changes.new('result/test-build-bin-only_2.10_amd64.changes')
      changes.parse!
      refute_equal([], changes.fields['files'].map(&:name))

      assert_path_exist('result/test-build-bin-only_2.10_amd64.deb.info.txt')
      # Should have plenty of characters (i.e. not be empty and probably contain
      # relevant output)
      assert(File.read('result/test-build-bin-only_2.10_amd64.deb.info.txt').size > 100)

      # Don't assert bin-only, it also includes the report, for auto bin-only
      # we have no report expectation.
      assert(builder.instance_variable_get(:@bin_only))
    end

    def test_arch_all_only_source
      FileUtils.cp_r("#{data}/.", Dir.pwd)
      builder = PackageBuilder.new

      DPKG.stubs(:architecture).returns('arm64')

      DPKG::Architecture.any_instance.expects(:is).with('amd64').returns(false)
      DPKG::Architecture.any_instance.expects(:is).with('all').returns(false)

      builder.expects(:extract)
             .never

      builder.build
    end

    def test_arm_on_amd64
      FileUtils.cp_r("#{data}/.", Dir.pwd)
      DPKG.stubs(:run)
          .with('dpkg-architecture', ['-qDEB_HOST_ARCH'])
          .returns(['amd64'])

      DPKG::Architecture.any_instance.expects(:is).with('armhf').returns(false)
      DPKG::Architecture.any_instance.expects(:is).with('arm64').returns(false)

      builder = PackageBuilder.new

      builder.expects(:extract)
             .never

      builder.build
    end

    def test_setcap_fail
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      builder = PackageBuilder.new
      assert_raise do
        builder.build_package
      end
    end

    def test_setcap_success
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      setcap = [['foo', '/workspace/yolo/bar']]

      FileUtils.mkpath('build/debian/')
      File.write('build/debian/setcap.yaml', YAML.dump(setcap))

      builder = PackageBuilder.new
      builder.build_package
    end

    def test_setcap_fail_missing
      # A setcap call was expected but not run.
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      setcap = [['foo', '/workspace/yolo/bar'], ['bar', 'foo']]

      FileUtils.mkpath('build/debian/')
      File.write('build/debian/setcap.yaml', YAML.dump(setcap))

      builder = PackageBuilder.new
      assert_raise CI::SetCapError do
        builder.build_package
      end
    end

    def test_setcap_subproc_fail
      # Make sure we don't get a setcap violation if the sub process failed.
      # It'd make reading build failures unnecessarily difficult.
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      setcap = [['foo', '/workspace/yolo/bar'], ['bar', 'foo']]

      FileUtils.mkpath('build/debian/')
      File.write('build/debian/setcap.yaml', YAML.dump(setcap))

      builder = PackageBuilder.new
      assert_raise RuntimeError do
        builder.build_package
      end
    end

    def test_setcap_pattern_success
      # Make sure a wildcard pattern also matches expectations
      FileUtils.cp_r("#{data}/.", Dir.pwd)

      setcap = [['foo', '*/bar']]

      FileUtils.mkpath('build/debian/')
      File.write('build/debian/setcap.yaml', YAML.dump(setcap))

      builder = PackageBuilder.new
      builder.build_package
    end
  end
end
