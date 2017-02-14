# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

    # Reset possible cached mirrors results.
    NCI::Mirrors.reset!

    ENV['TYPE'] = 'unstable'
  end

  def teardown
    WebMock.allow_net_connect!
    LSB.reset
    ENV.delete('TYPE')
  end

  def test_setup_repo
    system_calls = [
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'software-properties-common'],
      ['add-apt-repository', '-y',
       'deb http://archive.neon.kde.org/unstable vivid main'],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'python-setuptools']
    ]

    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    key_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(key_catcher)
      .returns(true)

    # stub_request(:get, 'http://mirrors.ubuntu.com/mirrors.txt')
    #   .to_return(status: 200, body: 'http://ubuntu.uni-klu.ac.at/ubuntu/')
    stub_request(:get, 'https://archive.neon.kde.org/public.key')
      .to_return(status: 200, body: 'abc')

    # Expect proxy to be set up to private
    NCI.expects(:connect_to_private_proxy).returns(true)
    File.expects(:write)
        .with('/etc/apt/apt.conf.d/proxy',
              'Acquire::http::Proxy "http://10.135.3.146:3142";')

    # mock_tcp_uni_klu = mock('mock_tcp_uni_klu')
    # mock_tcp_uni_klu.responds_like_instance_of(Net::Ping::TCP)
    # mock_tcp_uni_klu.stubs(:ping).at_least_once
    # mock_tcp_uni_klu.stubs(:exception).returns(nil)
    # mock_tcp_uni_klu.stubs(:host).returns('ubuntu.uni-klu.ac.at')
    # mock_tcp_uni_klu.stubs(:duration).returns(0.003)
    #
    # Net::Ping::TCP.expects(:new)
    #               .times(1)
    #               .with('ubuntu.uni-klu.ac.at', 80, 1)
    #               .returns(mock_tcp_uni_klu)

    # File.expects(:read)
    #     .with('/etc/apt/sources.list')
    #     .returns("deb http://archive.ubuntu.com/ubuntu/ willy yo\ndeb http://archive.neon.kde.org willy yo\n")
    # File.expects(:write)
    #     .with('/etc/apt/sources.list', "deb http://ubuntu.uni-klu.ac.at/ubuntu/ willy yo\ndeb http://archive.neon.kde.org willy yo\n")

    NCI.setup_repo!

    assert_equal("abc\n", key_catcher.string)
  end

  # This is a semi-temporary test until all servers have private networking
  # enabled. At which point we'll simply assume the proxy can be connected
  # to.
  def test_setup_repo_no_private
    system_calls = [
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'software-properties-common'],
      ['add-apt-repository', '-y',
       'deb http://archive.neon.kde.org/unstable vivid main'],
      ['apt-get', *Apt::Abstrapt.default_args, 'update'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'pkg-kde-tools'],
      ['apt-get', *Apt::Abstrapt.default_args, 'install', 'python-setuptools']
    ]

    system_sequence = sequence('system-calls')
    system_calls.each do |cmd|
      Object.any_instance.expects(:system)
            .with(*cmd)
            .returns(true)
            .in_sequence(system_sequence)
    end

    key_catcher = StringIO.new
    IO.expects(:popen)
      .with(['apt-key', 'add', '-'], 'w')
      .yields(key_catcher)
      .returns(true)

    # stub_request(:get, 'http://mirrors.ubuntu.com/mirrors.txt')
    #   .to_return(status: 200, body: 'http://ubuntu.uni-klu.ac.at/ubuntu/')
    stub_request(:get, 'https://archive.neon.kde.org/public.key')
      .to_return(status: 200, body: 'abc')

    # Expect proxy to be set up to public
    NCI.expects(:connect_to_private_proxy).raises(Net::OpenTimeout)
    File.expects(:write)
        .with('/etc/apt/apt.conf.d/proxy',
              'Acquire::http::Proxy "http://46.101.188.72:3142";')

    NCI.setup_repo!

    assert_equal("abc\n", key_catcher.string)
  end
end
