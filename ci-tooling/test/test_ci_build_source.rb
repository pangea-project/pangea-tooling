# frozen_string_literal: true
#
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require 'rubygems/package'
require 'zlib'

require_relative 'lib/assert_system'
require_relative 'lib/testcase'

require_relative '../lib/ci/build_source'
require_relative '../lib/debian/control'
require_relative '../lib/os'

class VCSBuilderTest < TestCase
  required_binaries %w(dpkg-buildpackage dpkg dh)

  REF_TIME = '20150717.1756'

  def fake_os(id, release, version)
    OS.reset
    @release = release
    OS.instance_variable_set(:@hash, VERSION_ID: version, ID: id)
  end

  def fake_os_ubuntu
    fake_os('ubuntu', 'vivid', '15.04')
  end

  def fake_os_debian
    fake_os('debian', 'unstable', '9')
  end

  def setup
    fake_os_ubuntu
    fake_os_debian if OS::ID == 'debian'
    alias_time
    FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
  end

  def teardown
    OS.reset
    unalias_time
  end

  def alias_time
    CI::BuildVersion.send(:alias_method, :__time_orig, :time)
    CI::BuildVersion.send(:define_method, :time) { REF_TIME }
    @time_aliased = true
  end

  def unalias_time
    return unless @time_aliased
    CI::BuildVersion.send(:undef_method, :time)
    CI::BuildVersion.send(:alias_method, :time, :__time_orig)
    @time_aliased = false
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

  def test_quilt
    s = CI::VcsSourceBuilder.new(release: @release)
    r = s.run
    assert_equal(:quilt, r.type)
    assert_equal('hello', r.name)
    assert_equal("2.10+git20150717.1756+#{OS::VERSION_ID}-0", r.version)
    assert_equal('hello_2.10+git20150717.1756+15.04-0.dsc', r.dsc)
    assert_not_nil(r.build_version)

    assert(File.read('last_version').start_with?('2.10+git'),
           "New version not recorded? -> #{File.read('last_version')}")
  end

  def test_native
    s = CI::VcsSourceBuilder.new(release: @release)
    r = s.run
    assert_equal(:native, r.type)
    assert_equal('hello', r.name)
    assert_equal("2.10+git20150717.1756+#{OS::VERSION_ID}", r.version)
    assert_equal('hello_2.10+git20150717.1756+15.04.dsc', r.dsc)
    assert_not_nil(r.build_version)

    # Make sure we have source files in our tarball.
    Dir.chdir('build/') do
      assert(system("dpkg-source -x #{r.dsc}"))
      assert_path_exist("#{r.name}-#{r.version}/debian")
      assert_path_exist("#{r.name}-#{r.version}/sourcey.file")
    end
  end

  def test_empty_install
    s = CI::VcsSourceBuilder.new(release: @release)
    r = s.run
    assert_equal(:native, r.type)
    assert_equal('hello', r.name)
    assert_equal("2.10+git20150717.1756+#{OS::VERSION_ID}", r.version)
    assert_not_nil(r.dsc)

    Dir.chdir('build/') do
      assert(system("dpkg-source -x #{r.dsc}"))
      assert(File.exist?("#{r.name}-#{r.version}/debian/#{r.name}.lintian-overrides"))
    end
  end

  def test_build_fail
    s = CI::VcsSourceBuilder.new(release: @release)
    assert_raise RuntimeError do
      s.run
    end
  end

  def test_symbols_keep
    CI::VcsSourceBuilder.new(release: KCI.latest_series).run
    Dir.chdir('build')
    tar = Dir.glob('*.tar.gz')
    assert_equal(1, tar.size)
    files = tar_file_list(tar[0])
    assert_include(files, 'symbols')
    assert_include(files, 'test.symbols')
    assert_include(files, 'test.symbols.armhf')
  end

  def test_symbols_strip
    oldest_series = KCI.series(sort: :descending).keys.last
    CI::VcsSourceBuilder.new(release: oldest_series).run
    Dir.chdir('build')
    tar = Dir.glob('*.tar.gz')
    assert_equal(1, tar.size)
    files = tar_file_list(tar[0])
    assert_not_include(files, 'symbols')
    assert_not_include(files, 'test.symbols')
    assert_not_include(files, 'test.symbols.armhf')
  end

  def test_symbols_strip_latest
    builder = CI::VcsSourceBuilder.new(release: KCI.latest_series, strip_symbols: true).run
    Dir.chdir('build')
    tar = Dir.glob('*.tar.gz')
    assert_equal(1, tar.size)
    files = tar_file_list(tar[0])
    assert_not_include(files, 'symbols')
    assert_not_include(files, 'test.symbols')
    assert_not_include(files, 'test.symbols.armhf')
  end

  def assert_changelogid(osid, author)
    send("fake_os_#{osid}".to_sym)
    source = CI::VcsSourceBuilder.new(release: @release).run
    assert_not_nil(source.dsc)
    Dir.chdir('build') do
      dsc = source.dsc
      changelog = "#{source.name}-#{source.version}/debian/changelog"
      assert(system('dpkg-source', '-x', dsc))
      line = File.read(changelog).split($/).fetch(4)
      assert_include(line, author)
    end
  end

  def test_changelog_ubuntu
    assert_changelogid('ubuntu',
                       ' -- Kubuntu CI <kubuntu-ci@lists.launchpad.net>')
  end

  def test_changelog_debian
    assert_changelogid('debian',
                       ' -- Debian CI <null@debian.org>')
  end

  def test_locale_kdelibs4support
    source = CI::VcsSourceBuilder.new(release: @release).run
    assert_not_nil(source.dsc)
    Dir.chdir('build') do
      dsc = source.dsc
      install = "#{source.name}-#{source.build_version.tar}/debian/" \
                'libkf5kdelibs4support-data.install'
      assert(system('dpkg-source', '-x', dsc))
      data = File.read(install).split($/)
      assert_include(data, 'usr/share/locale/*')
    end
  end

  def test_hidden_sources
    source = CI::VcsSourceBuilder.new(release: @release).run
    assert_not_nil(source.dsc)
    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      file = "#{source.name}-#{source.build_version.tar}/.hidden-file"
      assert_path_exist(file)
    end
  end

  def test_epoch_bump_fail
    File.write('last_version', '10:1.0')
    assert_raise CI::VersionEnforcer::UnauthorizedChangeError do
      CI::VcsSourceBuilder.new(release: @release).run
    end
  end

  def test_epoch_decrement_fail
    File.write('last_version', '1.0')
    assert_raise CI::VersionEnforcer::UnauthorizedChangeError do
      CI::VcsSourceBuilder.new(release: @release).run
    end
  end

  def test_epoch_retain
    File.write('last_version', '5:1.0')
    CI::VcsSourceBuilder.new(release: @release).run
    # pend "assert last_version changed"
    assert(File.read('last_version').start_with?('5:2.10'),
           "New version not recorded? -> #{File.read('last_version')}")
  end

  def test_ci_substvars
    source = CI::VcsSourceBuilder.new(release: @release).run
    assert_not_nil(source.dsc)
    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      dir = "#{source.name}-#{source.build_version.tar}/"
      assert_path_exist(dir)
      readme = "#{dir}/README"
      # Readme should not have been mangled.
      assert_equal("${ci:BuildVersion}\n", File.read(readme))
      control = Debian::Control.new(dir)
      control.parse!
      bin = control.binaries[0]
      replaces = bin['Replaces']
      assert_equal(1, replaces.size)
      replace = replaces[0]
      assert_equal('kitten', replace.name)
      assert_equal('<<', replace.operator)
      # version should be the actual version not the substvar
      assert_equal(source.version, replace.version)
    end
  end
end
