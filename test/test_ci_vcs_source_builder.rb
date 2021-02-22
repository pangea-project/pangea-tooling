# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015 Rohan Garg <rohan@garg.io>
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

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
  required_binaries %w[dpkg-buildpackage dpkg dh]

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

    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)

    CI::DependencyResolver.simulate = true

    # dud. only used for output in version enforcer
    ENV['JOB_NAME'] = 'RaRaRasputin'
    # Turn a bunch of debhelper sub process calls noop to improve speed.
    ENV['PATH'] = "#{__dir__}/dud-bin:#{ENV['PATH']}"
  end

  def teardown
    CI::DependencyResolver.simulate = false

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
    ENV['TYPE'] = 'nol10n'

    s = CI::VcsSourceBuilder.new(release: @release)
    r = s.run
    assert_equal(:quilt, r.type)
    assert_equal('hello', r.name)
    assert_equal("2.10+p#{OS::VERSION_ID}+git20150717.1756-0", r.version)
    assert_equal('hello_2.10+p15.04+git20150717.1756-0.dsc', r.dsc)
    assert_not_nil(r.build_version)

    assert(File.read('last_version').start_with?('2.10+p'),
           "New version not recorded? -> #{File.read('last_version')}")
  ensure
    ENV.delete('TYPE')
  end

  def test_native
    ENV['TYPE'] = 'nol10n'
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
  ensure
    ENV.delete('TYPE')
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
    ENV['TYPE'] = 'nol10n'
    s = CI::VcsSourceBuilder.new(release: @release)
    assert_raise CI::VcsSourceBuilder::BuildPackageError do
      s.run
    end
  end

  def test_symbols_strip_latest
    CI::VcsSourceBuilder.new(release: @release, strip_symbols: true).run
    Dir.chdir('build')
    tar = Dir.glob('*.tar.gz')
    assert_equal(1, tar.size)
    files = tar_file_list(tar[0])
    assert_not_include(files, 'symbols')
    assert_not_include(files, 'test.acc.in')
    assert_not_include(files, 'test.symbols')
    assert_not_include(files, 'test.symbols.armhf')
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
    ENV['TYPE'] = 'nol10n'
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
    ENV['TYPE'] = 'nol10n'
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

  # NOTE: this actually talks to the real life svn server and can flake
  #   when that happens chances are something actually moved in production.
  #   this is kinda intentional since this is a blackbox test!
  def test_l10n
    omit('Broken for unknown reasons on xenon. Works locally QQ')
    # The git dir is not called .git as to not confuse the actual tooling git.
    FileUtils.mv('source/gitty', 'source/.git')

    ENV['TYPE'] = 'stable'

    stub_request(:get, 'https://projects.kde.org/api/v1/repo/kmenuedit')
      .to_return(body: '{"i18n":{"stable":"none","stableKF5":"Plasma/5.10",
        "trunk":"none","trunkKF5":"master","component":"kde-workspace"},
        "path":"kde/workspace/kmenuedit","repo":"plasma/kmenuedit"}')

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

  def test_vcs_injection
    # Automatically inject/update the Vcs fields in the control file.

    # The git dir is not called .git as to not confuse the actual tooling git.
    FileUtils.mv('packaging/gitty', 'packaging/.git')

    source = CI::VcsSourceBuilder.new(release: @release).run
    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      dir = "#{source.name}-#{source.build_version.tar}/"
      assert_path_exist(dir)
      data = File.read("#{dir}/debian/control").strip
      assert_include(data, 'Vcs-Git: https://invent.kde.org/neon/kde/kmenuedit.git')
      assert_include(data, 'Vcs-Browser: https://invent.kde.org/neon/kde/kmenuedit')
    end
  end

  def test_maintainer_mangle
    orig_name = ENV['DEBFULLNAME']
    orig_email = ENV['DEBEMAIL']
    ENV['DEBFULLNAME'] = 'xxNeon CIxx'
    ENV['DEBEMAIL'] = 'xxnull@neon.orgxx'

    source = CI::VcsSourceBuilder.new(release: @release).run

    Dir.chdir('build') do
      dsc = source.dsc
      assert(system('dpkg-source', '-x', dsc))
      dir = "#{source.name}-#{source.build_version.tar}/"
      assert_path_exist(dir)
      assert_include(File.read("#{dir}/debian/control").strip,
                     'Maintainer: xxNeon CIxx <xxnull@neon.orgxx>')
      assert_include(File.read("#{dir}/debian/changelog").strip,
                     '-- xxNeon CIxx <xxnull@neon.orgxx>')
    end
  ensure
    orig_name ? ENV['DEBFULLNAME'] = orig_name : ENV.delete('DEBFULLNAME')
    orig_email ? ENV['DEBEMAIL'] = orig_email : ENV.delete('DEBEMAIL')
  end

  def test_l10n_neon_url
    # Make sure neon git urls do not trigger l10n injection code.
    r = CI::VcsSourceBuilder
        .new(release: @release)
        .send(:repo_url_from_path, 'https://invent.kde.org/neon')
    assert_equal(nil, r)
  end

  def test_build_fail_resolution
    # Special build fail which actually comes out of a resolution problem.
    # This only tests if the ResolutionError gets transformed into a BuildPackageError
    ENV['TYPE'] = 'nol10n'
    CI::DependencyResolver
      .expects(:resolve)
      .raises(CI::DependencyResolver::ResolutionError)

    s = CI::VcsSourceBuilder.new(release: @release)
    assert_raise CI::VcsSourceBuilder::BuildPackageError do
      s.run
    end
  end

  def test_l10n_origin_no_stable_fallback
    # When a project has no stable branch but stable was requested we expect
    # a fallback to trunk instead.
    r = CI::VcsSourceBuilder.new(release: @release)
    ENV['TYPE'] = 'stable'
    project = stub('project')
    project.expects(:i18n_stable).returns(nil)
    project.expects(:i18n_trunk).returns('master')
    origin = r.send(:l10n_origin_for, project)
    assert_equal(:trunk, origin)
  end

  def test_l10n_origin_no_stable_and_no_trunk
    # When a project has no i18n set at all fail fatally. This should not happen
    # and indicates a problem with the project configuration.
    r = CI::VcsSourceBuilder.new(release: @release)
    ENV['TYPE'] = 'stable'
    project = stub('project')
    project.expects(:i18n_stable).returns(nil)
    project.expects(:i18n_trunk).returns(nil)
    assert_raises do
      r.send(:l10n_origin_for, project)
    end
  end
end
