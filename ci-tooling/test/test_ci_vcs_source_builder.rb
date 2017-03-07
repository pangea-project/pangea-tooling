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

require_relative '../lib/ci/vcs_source_builder'
require_relative '../lib/debian/control'
require_relative '../lib/os'

require 'mocha/test_unit'
require 'webmock/test_unit'

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

    KCI.instance_variable_set(:@data, 'series' => { 'xenial' => '16.04',
                                                    'wily' => '15.10' })

    CI::SourceBuilderL10nExtension.disable_l10n_injection

    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def teardown
    CI::SourceBuilderL10nExtension.disable_l10n_injection
    KCI.send(:reset!)
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
    assert_equal("2.10+p#{OS::VERSION_ID}+git20150717.1756-0", r.version)
    assert_equal('hello_2.10+p15.04+git20150717.1756-0.dsc', r.dsc)
    assert_not_nil(r.build_version)

    assert(File.read('last_version').start_with?('2.10+p'),
           "New version not recorded? -> #{File.read('last_version')}")
  end

  def test_native
    s = CI::VcsSourceBuilder.new(release: @release)
    r = s.run
    assert_equal(:native, r.type)
    assert_equal('hello', r.name)
    assert_equal("2.10+p#{OS::VERSION_ID}+git20150717.1756", r.version)
    assert_equal('hello_2.10+p15.04+git20150717.1756.dsc', r.dsc)
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
    assert_equal("2.10+p#{OS::VERSION_ID}+git20150717.1756", r.version)
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

  def test_quilt_full_source
    source = CI::VcsSourceBuilder.new(release: @release,
                                      restricted_packaging_copy: true).run
    assert_equal(:quilt, source.type)
    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      dir = "#{source.name}-#{source.build_version.tar}/"
      assert_path_exist(dir)
      assert_path_not_exist("#{dir}/full_source1")
      assert_path_not_exist("#{dir}/full_source2")
    end
  end

  def test_l10n
    # The git dir is not called .git as to not confuse the actual tooling git.
    FileUtils.mv('source/gitty', 'source/.git')

    CI::SourceBuilderL10nExtension.enable_l10n_injection
    ENV['TYPE'] = 'stable'

    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', '-q', 'install', 'subversion')
      .returns(true)

    stub_request(:get, 'https://projects.kde.org/kde_projects.xml')
      .to_return(body: File.read(data('kde_projects.xml')))

    source = CI::VcsSourceBuilder.new(release: @release).run

    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      dir = "#{source.name}-#{source.build_version.tar}/"
      assert_path_exist(dir)
      assert_path_exist("#{dir}/po")
      assert_path_exist("#{dir}/po/x-test")
      assert_equal(File.read("#{dir}/debian/hello.install").strip,
                   'usr/share/locale/')
    end
  ensure
    ENV.delete('TYPE')
  end
end
