require 'thread'
require 'net/ssh'

class Net::SSH::SocketGateway
  def initialize(host, user, options={})
    @session = Net::SSH.start(host, user, options)
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
