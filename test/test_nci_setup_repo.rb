# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>

require_relative '../nci/lib/setup_repo'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class NCISetupRepoTest < TestCase
  def setup
    OS.instance_variable_set(:@hash, VERSION_CODENAME: 'vivid')

    # Reset caching.
    Apt::Repository.send(:reset)
    # Disable bionic compat check (always assume true)
    Apt::Repository.send(:instance_variable_set, :@disable_auto_update, true)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never
    # Don't actually sleep.
    Object.any_instance.stubs(:sleep)
    # Disable all web (used for key).
    WebMock.disable_net_connect!

    NCI.reset_setup_repo
    FileUtils.cp(File.join(datadir, 'sources.list'), '.')
    NCI.default_sources_file = File.join(Dir.pwd, 'sources.list')

    ENV['TYPE'] = 'unstable'
    # Prevent this call from going through to the live data it'd change
    # the expectations as deblines are mutates based on this.
    NCI.stubs(:divert_repo?).returns(false)
  end

  def teardown
    NCI.reset_setup_repo

    Apt::Repository.send(:reset)

    WebMock.allow_net_connect!
    OS.reset
    ENV.delete('TYPE')
  end

  def add_key_args
    ['apt-key', 'adv', '--keyserver', 'keyserver.ubuntu.com', '--recv',
     '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D']
  end

  def expect_key_add
    # Internal query if the key had been added already
    Object
      .any_instance
      .stubs(:`)
      .with("apt-key adv --fingerprint '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D'")
    # Actual key adding (always run since the above comes back nil)
    Object
      .any_instance
      .expects(:system)
      .with(*add_key_args)
  end

  def proxy_enabled
    "Acquire::http::Proxy \"#{NCI::PROXY_URI}\";"
  end

  def test_setup_repo
    system_calls = [
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'software-properties-common'],
      ['add-apt-repository', '--no-update', '-y',
       'deb http://archive.neon.kde.org/unstable vivid main']
    ]

    NCI.series.each_key do |series|
      File
        .expects(:write)
        .with("/etc/apt/sources.list.d/neon_src_#{series}.list",
              "deb-src http://archive.neon.kde.org/unstable #{series} main\ndeb http://archive.neon.kde.org/unstable #{series} main")
        .returns(5000)
    end
    # Also disables deb-src in the main sources.list
    File
      .expects(:write)
      .with("#{Dir.pwd}/sources.list", "deb xxx\n# deb-src yyy")

    system_calls += [
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools', 'debhelper', 'cmake', 'quilt', 'dh-python', 'dh-translations']
    ]

    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    expect_key_add.returns(true)

    # Expect proxy to be set up to private
    File.expects(:write).with('/etc/apt/apt.conf.d/proxy', proxy_enabled)
    # With source also sets up a default release.
    File.expects(:write).with('/etc/apt/apt.conf.d/99-default',
                              "APT::Default-Release \"vivid\";\n")

    NCI.setup_repo!(with_source: true)
  end

  # This is a semi-temporary test until all servers have private networking
  # enabled. At which point we'll simply assume the proxy can be connected
  # to.
  def test_setup_repo_no_private
    system_calls = [
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'software-properties-common'],
      ['add-apt-repository', '--no-update', '-y',
       'deb http://archive.neon.kde.org/unstable vivid main'],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools', 'pkg-kde-tools-neon', 'debhelper', 'cmake', 'quilt', 'dh-python', 'dh-translations']
    ]

    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    expect_key_add.returns(true)

    # Expect proxy to be set up
    File.expects(:write).with('/etc/apt/apt.conf.d/proxy', proxy_enabled)

    NCI.setup_repo!
  end

  def test_add_repo
    # Expect proxy to be set up
    File.expects(:write).with('/etc/apt/apt.conf.d/proxy', proxy_enabled)

    NCI.setup_proxy!
  end

  def test_key_retry_fail
    # Retries at least twice in error. Should raise something.
    expect_key_add
      .at_least(2)
      .returns(false)

    assert_raises do
      NCI.add_repo_key!
    end
  end

  def test_key_retry_success
    # Make sure adding a key is retired. While adding from key servers is much
    # more reliable than https it still can fail occasionally.

    add_seq = sequence('key_add_fails')

    # Retries 2 times in error, then once in success
    expect_key_add
      .times(2)
      .in_sequence(add_seq)
      .returns(false)
    expect_key_add
      .once
      .in_sequence(add_seq)
      .returns(true)

    NCI.add_repo_key!
    # Add key after a successful one should be noop.
    NCI.add_repo_key!
  end

  def test_preference
    Apt::Preference.config_dir = Dir.pwd

    NCI.stubs(:future_series).returns('peppa')

    ENV['DIST'] = 'woosh'
    NCI.maybe_setup_apt_preference
    assert_path_not_exist('pangea-neon')

    # Only ever active on future series
    ENV['DIST'] = 'peppa'
    NCI.maybe_setup_apt_preference
    assert_path_exist('pangea-neon')
    assert_not_equal('', File.read('pangea-neon'))
  ensure
    Apt::Preference.config_dir = nil
  end

  def test_no_preference_teardowns
    Apt::Preference.config_dir = Dir.pwd

    NCI.stubs(:future_series).returns('peppa')

    ENV['DIST'] = 'peppa'
    NCI.maybe_setup_apt_preference # need an object, content is irrelevant
    assert_path_exist('pangea-neon')
    NCI.maybe_teardown_apt_preference
    assert_path_not_exist('pangea-neon')

    # When there is no preference object this should be noop
    File.write('pangea-neon', '')
    NCI.maybe_teardown_apt_preference
    assert_path_exist('pangea-neon')
    File.delete('pangea-neon')
  ensure
    Apt::Preference.config_dir = nil
  end

  def test_codename
    assert_equal('vivid', NCI.setup_repo_codename)
    NCI.setup_repo_codename = 'xx'
    assert_equal('xx', NCI.setup_repo_codename)
    NCI.reset_setup_repo
    assert_equal('vivid', NCI.setup_repo_codename)
  end

  def test_debline_divert
    NCI.expects(:divert_repo?).with('unstable').returns(true)
    assert_equal(NCI.send(:debline),
                 'deb http://archive.neon.kde.org/tmp/unstable vivid main')
  end

  def test_debline_no_divert
    NCI.expects(:divert_repo?).with('unstable').returns(false)
    assert_equal(NCI.send(:debline),
                 'deb http://archive.neon.kde.org/unstable vivid main')
  end

  def test_debsrcline_divert
    NCI.expects(:divert_repo?).with('unstable').returns(true)
    assert_equal(NCI.send(:debsrcline),
                 'deb-src http://archive.neon.kde.org/tmp/unstable vivid main')
  end

  def test_debsrcline_no_divert
    NCI.expects(:divert_repo?).with('unstable').returns(false)
    assert_equal(NCI.send(:debsrcline),
                 'deb-src http://archive.neon.kde.org/unstable vivid main')
  end
end
