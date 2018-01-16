# frozen_string_literal: true
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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

require 'logger'
require 'net/ssh'
require 'thread'

class Net::SSH::SocketGateway
  def initialize(host, user, options={})
    @session = Net::SSH.start(host, user, options)
    attach_logger(@session)
    @session_mutex = Mutex.new
    @loop_wait = options.delete(:loop_wait) || 0.001
    initiate_event_loop!
  end

  def active?
    @active
  end

  def shutdown!
    return unless active?

    @active = false
    @thread.join

    @session_mutex.synchronize do
      @session.forward.active_local_sockets.each do |local_socket_path|
        @session.forward.cancel_local_socket(local_socket_path)
      end
    end

    @session.close
  end

  def open(local_socket_path, remote_socket_path)
    @session_mutex.synchronize do
      @session.forward.local_socket(local_socket_path, remote_socket_path)
    end

    if block_given?
      begin
        yield local_socket_path
      ensure
        close(local_socket_path)
      end
      return nil
    end

    local_socket_path
  end

  def close(local_socket_path)
    @session_mutex.synchronize do
      @session.forward.cancel_local_socket(local_socket_path)
    end
  end

  private

  def attach_logger(netsshobj)
    # No littering when testing please.
    return if ENV.include?('PANGEA_UNDER_TEST')
    # :nocov:
    log_file = "/tmp/net-ssh-#{$$}-#{netsshobj.object_id.abs}.log"
    File.write(log_file, '')
    File.chmod(0o600, log_file)
    netsshobj.logger = Logger.new(log_file).tap do |l|
      l.progname = $PROGRAM_NAME.split(' ', 2)[0]
      l.level = Logger::DEBUG
    end
    netsshobj.logger.warn(ARGV.inspect)
    warn(log_file)
    # :nocov:
  end

  # Fires up the gateway session's event loop within a thread, so that it
  # can run in the background. The loop will run for as long as the gateway
  # remains active.
  def initiate_event_loop!
    @active = true

    @thread = Thread.new do
      while @active
        @session_mutex.synchronize do
          @session.process(@loop_wait)
        end
        Thread.pass
      end
    end
  end
end
