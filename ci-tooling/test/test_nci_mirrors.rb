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

require_relative '../nci/lib/mirrors'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class NCISetupRepoTest < TestCase
  def setup
    # Don't actually sleep.
    Object.any_instance.stubs(:sleep) # Don't actually sleep.
    WebMock.disable_net_connect!
    # Reset possible cached mirrors results.
    NCI::Mirrors.reset!
  end

  def teardown
    WebMock.allow_net_connect!
  end

  def test_best_of_two
    # Make sure we get archive.ubuntu as best with a lower best ping than
    stub_request(:get, 'http://mirrors.ubuntu.com/mirrors.txt')
      .to_return(status: 200, body: "http://ubuntu.uni-klu.ac.at/ubuntu/\nhttp://archive.ubuntu.com/ubuntu/")

    mock_tcp_uni_klu = mock('ubuntu.uni-klu.ac.at')
    mock_tcp_uni_klu.responds_like_instance_of(Net::Ping::TCP)
    mock_tcp_uni_klu.stubs(:ping).at_least_once
    mock_tcp_uni_klu.stubs(:exception).returns(nil)
    mock_tcp_uni_klu.stubs(:host).returns('ubuntu.uni-klu.ac.at')
    mock_tcp_uni_klu.stubs(:duration).returns(0.321).then.returns(0.213)

    Net::Ping::TCP.expects(:new)
                  .with('ubuntu.uni-klu.ac.at', 80, 1)
                  .returns(mock_tcp_uni_klu)

    mock_tcp_archive = mock('archive.ubuntu.com')
    mock_tcp_archive.responds_like_instance_of(Net::Ping::TCP)
    mock_tcp_archive.stubs(:ping).at_least_once
    mock_tcp_archive.stubs(:exception).returns(nil)
    mock_tcp_archive.stubs(:host).returns('archive.ubuntu.com')
    mock_tcp_archive.stubs(:duration).returns(0.231).then.returns(0.123)

    Net::Ping::TCP.expects(:new)
                  .with('archive.ubuntu.com', 80, 1)
                  .returns(mock_tcp_archive)

    assert_equal('http://archive.ubuntu.com/ubuntu/', NCI::Mirrors.best)
  end

  def test_pinger_fail
    stub_request(:get, 'http://mirrors.ubuntu.com/mirrors.txt')
      .to_return(status: 200, body: 'http://ubuntu.uni-klu.ac.at/ubuntu/')

    mock_tcp_uni_klu = mock('ubuntu.uni-klu.ac.at')
    mock_tcp_uni_klu.responds_like_instance_of(Net::Ping::TCP)
    mock_tcp_uni_klu.stubs(:ping).at_least_once
    mock_tcp_uni_klu.stubs(:exception).returns(IOError.new)
    mock_tcp_uni_klu.stubs(:host).returns('ubuntu.uni-klu.ac.at')

    Net::Ping::TCP.expects(:new)
                  .twice # Once for Pinger, once for Mirrors
                  .with('ubuntu.uni-klu.ac.at', 80, 1)
                  .returns(mock_tcp_uni_klu)

    pinger = NCI::Mirrors::Pinger.new('http://ubuntu.uni-klu.ac.at/ubuntu/')

    assert_equal(nil, pinger.best_time)
    assert_equal(nil, NCI::Mirrors.best)
  end
end
