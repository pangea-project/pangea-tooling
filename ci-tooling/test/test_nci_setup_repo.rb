# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
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
    # Make sure $? is fine before we start!
    reset_child_status!
    # Disable all system invocation.
    Object.any_instance.expects(:`).never
    Object.any_instance.expects(:system).never
    # Disable all web (used for key).
    WebMock.disable_net_connect!
  end

  def teardown
    WebMock.allow_net_connect!
    LSB.reset
  end

  def test_setup_repo
    system_calls = [
      ['apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'update'],
      ['apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'install', 'software-properties-common'],
      ['add-apt-repository', '-y', 'deb http://archive.neon.kde.org.uk/unstable vivid main'],
      ['apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'update'],
      ['apt-get', '-y', '-o', 'APT::Get::force-yes=true', '-o', 'Debug::pkgProblemResolver=true', 'install', 'pkg-kde-tools']
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

    stub_request(:get, 'http://archive.neon.kde.org.uk/public.key')
      .to_return(status: 200, body: 'abc')

    NCI.setup_repo!

    assert_equal("abc\n", key_catcher.string)
  end
end
