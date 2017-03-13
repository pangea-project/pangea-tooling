# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative '../ci-tooling/test/lib/testcase'

require_relative '../lib/aptly-ext/remote'

require 'mocha/test_unit'

module Aptly::Ext
  class RemoteTest < TestCase
    def test_connects_with_path
      uri = URI::Generic.build(scheme: 'ssh', user: 'u', host: 'h', port: 1,
                               path: '/xxx')
      assert(Remote::Socket.connects?(uri))
      assert_false(Remote::TCP.connects?(uri))
    end

    def test_connects_without_path
      uri = URI::Generic.build(scheme: 'ssh', user: 'u', host: 'h', port: 1)
      assert(Remote::TCP.connects?(uri))
      assert_false(Remote::Socket.connects?(uri))
    end

    def test_connect_socket
      uri = URI::Generic.build(scheme: 'ssh', user: 'u', host: 'h', port: 1,
                               path: '/xxx')

      Remote::TCP.expects(:connect).never

      session = mock('session')
      session.stubs(:process)
      session.expects(:close)
      Net::SSH.expects(:start).returns(session)

      forward = mock('forward')
      forward.expects(:local_socket).returns('/abc123')
      forward.stubs(:active_local_sockets).returns(['/abc123'])
      forward.expects(:cancel_local_socket).with('/abc123')
      session.stubs(:forward).returns(forward)

      Remote.connect(uri) {}
    end

    def test_connect_tcp
      uri = URI::Generic.build(scheme: 'ssh', user: 'u', host: 'h', port: 1)

      Remote::Socket.expects(:connect).never

      session = mock('session')
      session.stubs(:process)
      session.expects(:close)
      Net::SSH.expects(:start).returns(session)

      forward = mock('forward')
      forward.expects(:local).returns(65_535)
      forward.stubs(:active_locals).returns([65_535])
      forward.expects(:cancel_local).with(65_535)
      session.stubs(:forward).returns(forward)

      Remote.connect(uri) {}
    end
  end
end
