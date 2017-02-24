# -*- coding: utf-8 -*-
require 'net/ssh/loggable'

module Net; module SSH; module Service
  module SocketForward
    def initialize(*)
      @remote_forwarded_ports = {}
      super
    end

    def local_socket(local_socket_path, remote_socket_path)
      File.delete(local_socket_path) if File.exist?(local_socket_path)
      socket = Socket.unix_server_socket(local_socket_path)

      @local_forwarded_ports[local_socket_path] = socket

      session.listen_to(socket) do |server|
        client = server.accept[0]
        debug { "received connection on #{socket}" }

        channel = session.open_channel("direct-streamlocal@openssh.com",
                                       :string, remote_socket_path,
                                       :string, nil,
                                       :long, 0) do |achannel|
          achannel.info { "direct channel established" }
        end

        prepare_client(client, channel, :local)

        channel.on_open_failed do |ch, code, description|
          channel.error { "could not establish direct channel: #{description} (#{code})" }
          session.stop_listening_to(channel[:socket])
          channel[:socket].close
        end
      end

      local_socket_path
    end

    def cancel_local_socket(local_socket_path)
      socket = @local_forwarded_ports.delete(local_socket_path)
      socket.shutdown rescue nil
      socket.close rescue nil
      session.stop_listening_to(socket)
    end


    def active_local_sockets
      @local_forwarded_ports.keys
    end
  end

  class Forward
    prepend SocketForward
  end
end; end; end
