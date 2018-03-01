# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require_relative '../nci/lib/setup_repo'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class NCISetupRepoTest < TestCase
  def setup
    LSB.instance_variable_set(:@hash, DISTRIB_CODENAME: 'vivid')

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

    ENV['TYPE'] = 'unstable'
  end

  def teardown
    NCI.reset_setup_repo

    Apt::Repository.send(:reset)

    WebMock.allow_net_connect!
    LSB.reset
    ENV.delete('TYPE')
  end

  def add_key_args
    ['apt-key', 'adv', '--keyserver', 'keyserver.ubuntu.com', '--recv',
     '444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D']
  end

  def expect_key_add
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
       'deb http://archive.neon.kde.org/unstable vivid main'],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools']
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

    NCI.setup_repo!
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
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools']
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
end
