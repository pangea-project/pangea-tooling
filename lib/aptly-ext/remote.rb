# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@garg.io>
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

require 'aptly'
require 'net/ssh/gateway'
require 'tmpdir'

require_relative '../net/ssh/socket_gateway.rb'

module Aptly
  module Ext
    # SSH gateway connectors
    module Remote
      def self.connect(uri, &block)
        constants.each do |const|
          klass = const_get(const)
          next unless klass.connects?(uri)
          klass.connect(uri, &block)
        end
      end

      # Connects directly through HTTP
      module HTTP
        module_function

        def connects?(uri)
          uri.scheme == 'http'
        end

        def connect(uri, &_block)
          Aptly.configure do |config|
            config.uri = uri
          end
          yield
        end
      end

      # Gateway connects through a TCP socket/port to a remote aptly.
      module TCP
        module_function

        def connects?(uri)
          uri.scheme == 'ssh' && uri.path.empty?
        end

        def connect(uri, &_block)
          open_gateway(uri) do |port|
            Aptly.configure do |config|
              config.uri = URI::HTTP.build(host: 'localhost', port: port)
            end
            yield
          end
        end

        # @yield [String] port on localhost
        def open_gateway(uri, &_block)
          gateway = Net::SSH::Gateway.new(uri.host, uri.user)
          yield gateway.open('localhost', uri.port.to_s)
        ensure
          gateway.shutdown! if gateway
        end
      end

      # Gateway connects through a unix domain socket to a remote aptly.
      module Socket
        module_function

        def connects?(uri)
          uri.scheme == 'ssh' && !uri.path.empty?
        end

        def connect(uri, &_block)
          open_gateway(uri) do |local_socket|
            Aptly.configure do |config|
              config.uri = URI::Generic.build(scheme: 'unix',
                                              path: local_socket)
            end
            yield
          end
        end

        # @yield [String] port on localhost
        def open_gateway(uri, &_block)
          Dir.mktmpdir('aptly-socket') do |tmpdir|
            begin
              gateway = Net::SSH::SocketGateway.new(uri.host, uri.user)
              yield gateway.open("#{tmpdir}/aptly.sock", uri.path)
            ensure
              gateway.shutdown! if gateway
            end
          end
        end
      end
    end
  end
end
