# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2016 Bhushan Shah <bhush94@gmail.com>
# SPDX-FileCopyrightText: 2016-2017 Rohan Garg <rohan@garg.io>

require 'rubygems/package'

require_relative 'lib/testcase'
require_relative '../lib/ci/orig_source_builder'
require_relative '../lib/ci/tarball'

module CI
  class OrigSourceBuilderTest < TestCase
    required_binaries %w[dpkg-buildpackage dpkg dh uscan]

    def setup
      LSB.reset
      LSB.instance_variable_set(:@hash, DISTRIB_CODENAME: 'vivid', DISTRIB_RELEASE: '15.04')
      OS.reset
      OS.instance_variable_set(:@hash, VERSION_ID: '15.04')
      ENV['BUILD_NUMBER'] = '3'
      ENV['DIST'] = 'vivid'
      ENV['TYPE'] = 'unstable'
      @tarname = 'dragon_15.08.1.orig.tar.xz'
      @tarfile = "#{Dir.pwd}/#{@tarname}"
      FileUtils.cp_r(Dir.glob("#{data}/."), Dir.pwd)
      FileUtils.cp_r("#{datadir}/http/dragon-15.08.1.tar.xz", @tarfile)

      CI::DependencyResolver.simulate = true

      # Turn a bunch of debhelper sub process calls noop to improve speed.
      ENV['PATH'] = "#{__dir__}/dud-bin:#{ENV['PATH']}"
    end

    def teardown
      CI::DependencyResolver.simulate = false

      LSB.reset
      OS.reset
    end

    def tar_file_list(path)
      files = []
      Gem::Package::TarReader.new(Zlib::GzipReader.open(path)).tap do |reader|
        reader.rewind
        reader.each do |entry|
          files << File.basename(entry.full_name) if entry.file?
        end
        reader.close
      end
      files
    end

    def test_run
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new
      builder.build(tarball)

      # On 14.04 the default was .gz, newer versions may yield .xz
      debian_tar = Dir.glob('build/dragon_15.08.1-0xneon+15.04+vivid+unstable+build3.debian.tar.*')
      assert_false(debian_tar.empty?, "no tar #{Dir.glob('build/*')}")
      assert_path_exist('build/dragon_15.08.1-0xneon+15.04+vivid+unstable+build3_source.changes')
      assert_path_exist('build/dragon_15.08.1-0xneon+15.04+vivid+unstable+build3.dsc')
      puts File.read('build/dragon_15.08.1-0xneon+15.04+vivid+unstable+build3.dsc')
      assert_path_exist('build/dragon_15.08.1.orig.tar.xz')
      changes = File.read('build/dragon_15.08.1-0xneon+15.04+vivid+unstable+build3_source.changes')
      assert_include(changes.split($/), 'Distribution: vivid')
      # Neon builds should have -0neon changed to -0xneon so we exceed ubuntu's
      # -0ubuntu in case they have the same upstream version. This is pretty
      # much only useful for when restaging on a newer ubuntu base, where the
      # versions may initially overlap.
      assert_include(changes.split($/), 'Version: 4:15.08.1-0xneon+15.04+vivid+unstable+build3')
    end

    def test_existing_builddir
      # Now with build dir.
      Dir.mkdir('build')
      assert_nothing_raised do
        OrigSourceBuilder.new
      end
      assert_path_exist('build')
    end

    def test_unreleased_changelog
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new(release: 'unstable')
      builder.build(tarball)

      debian_tar = Dir.glob('build/dragon_15.08.1-0+15.04+vivid+unstable+build3.debian.tar.*')
      assert_false(debian_tar.empty?, "no tar #{Dir.glob('build/*')}")
      assert_path_exist('build/dragon_15.08.1-0+15.04+vivid+unstable+build3_source.changes')
      assert_path_exist('build/dragon_15.08.1-0+15.04+vivid+unstable+build3.dsc')
      assert_path_exist('build/dragon_15.08.1.orig.tar.xz')
      changes = File.read('build/dragon_15.08.1-0+15.04+vivid+unstable+build3_source.changes')
      assert_include(changes.split($/), 'Distribution: unstable')
    end

    def test_symbols_strip
      assert_false(Dir.glob('*').empty?)

      tarball = Tarball.new(@tarfile)

      builder = OrigSourceBuilder.new(strip_symbols: true)
      builder.build(tarball)
      Dir.chdir('build') do
        tar = Dir.glob('*.debian.tar.gz')
        assert_equal(1, tar.size, "Could not find debian tar #{Dir.glob('*')}")
        files = tar_file_list(tar[0])
        assert_not_include(files, 'symbols')
        assert_not_include(files, 'dragonplayer.symbols')
        assert_not_include(files, 'dragonplayer.symbols.armhf')
      end
    end

    def test_experimental_suffix
      # Experimental TYPE should cause a suffix including ~exp before build
      # number to ensure it doesn't exceed the number of "proper" types

      ENV['TYPE'] = 'experimental'
      tarball = Tarball.new(@tarfile)
      builder = OrigSourceBuilder.new(release: 'unstable')
      builder.build(tarball)

      assert_path_exist('build/dragon_15.08.1-0xneon+15.04+vivid~exp+experimental+build3_source.changes')
    end
  end
end
