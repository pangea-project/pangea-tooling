# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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
require 'logger/colors'
require 'timeout'

require_relative 'container/ephemeral'
require_relative 'pangeaimage'

module CI
  # Containment class sitting on top of an {EphemeralContainer}.
  class Containment
    TRAP_SIGNALS = %w[EXIT HUP INT QUIT TERM].freeze

    class << self
      attr_accessor :no_attach
    end

    attr_reader :name
    attr_reader :image
    attr_reader :binds
    attr_reader :privileged
    attr_reader :trap_run

    def initialize(name, image:, binds: [Dir.pwd], privileged: false,
                   no_exit_handlers: privileged)
      EphemeralContainer.assert_version

      @name = name
      @image = image # Can be a PangeaImage
      @binds = binds
      @privileged = privileged
      @log = new_logger
      @trap_run = false
      init(no_exit_handlers)
    end

    def cleanup
      c = EphemeralContainer.get(@name)
      @log.info 'Cleaning up previous container.'
      c.kill
      c.remove(force: true)
    rescue Docker::Error::NotFoundError
      @log.info 'Not cleaning up, no previous container found.'
    end

    def default_create_options
      @default_args ||= {
        # Internal
        binds: @binds,
        # Docker
        # Can be a PangeaImage instance
        Image: @image.to_str,
        HostConfig: {
          Privileged: @privileged
        }
      }

      @default_args[:HostConfig][:UsernsMode] = 'host' if @privileged
      @default_args
    end

    def contain(user_args)
      args = default_create_options.dup
      args.merge!(user_args)
      cleanup
      c = EphemeralContainer.create(args)
      c.rename(@name)
      c
    end

    def attach_thread(container)
      Thread.new do
        # The log attach is threaded because
        # - attaching after start might attach to what is already stopped again
        #   in which case attach runs until timeout
        # - after start we do an explicit wait to get the correct status code so
        #   we can exit accordingly

        # This code only gets run when the socket pushes something, we cannot
        # mock this right now unfortunately.
        # :nocov:
        container.attach do |stream, chunk|
          io = stream == 'stderr' ? STDERR : STDOUT
          io.print(chunk)
          io.flush if chunk.end_with?("\n")
        end
        # Make sure everything is flushed before we proceed. So that container
        # output is fully consistent at this point.
        STDOUT.flush
        # :nocov:
      end
    end

    def run(args)
      c = contain(args)
      # FIXME: port to logger
      stdout_thread = attach_thread(c) unless self.class.no_attach
      return rescued_start(c)
    ensure
      if defined?(stdout_thread) && !stdout_thread.nil?
        stdout_thread.join(16) || stdout_thread.kill
      end
    end

    private

    def new_logger
      Logger.new(STDERR).tap do |l|
        l.level = Logger::INFO
        l.progname = self.class
      end
    end

    def chown_any_mapped(binds)
      # /a:/build gets split into /a we then 1:1 map this as /a upon chowning.
      # This allows us to hopefully reliably chown mapped bindings.
      DirectBindingArray.to_volumes(binds).keys
    end

    def chown_handler
      STDERR.puts 'Running chown handler'
      return @chown_handler if defined?(@chown_handler)
      binds_ = @binds.dup # Remove from object context so Proc can be a closure.
      binds_ = chown_any_mapped(binds_)
      @chown_handler = proc do
        chown_container =
          CI::Containment.new("#{@name}_chown", image: @image, binds: binds_,
                                                no_exit_handlers: true)
        chown_container.run(Cmd: %w[chown -R jenkins:jenkins] + binds_)
      end
    end

    def trap!
      TRAP_SIGNALS.each do |signal|
        previous = Signal.trap(signal, nil)
        Signal.trap(signal) do
          STDERR.puts 'Running cleanup and handlers'
          cleanup
          run_signal_handler(signal, chown_handler)
          run_signal_handler(signal, previous)
        end
      end
      @trap_run = true
    end

    def run_signal_handler(signal, handler)
      if !handler || !handler.respond_to?(:call)
        # Default traps are strings, we can't call them.
        case handler
        when 'IGNORE', 'SIG_IGN'
          # Skip ignores, all others we want to raise.
          return
        end
        handler = proc { raise SignalException, signal }
      end
      # Sometimes the chown handler gets stuck running chown_container.run
      # so make sure to timeout whatever is going on and get everything murdered
      Timeout.timeout(16) { handler.call }
    rescue Timeout::Error => e
      warn "Failed to run handler #{handler}, timed out. #{e}"
    end

    def rescued_start(c)
      c.start
      status_code = c.wait.fetch('StatusCode', 1)
      debug(c) unless status_code.zero?
      c.stop
      status_code
    rescue Docker::Error::NotFoundError => e
      @log.error 'Failed to create container!'
      @log.error e.to_s
      return 1
    end

    def debug(c)
      json = c.json
      warn json.fetch('State', json)
    end

    def init(no_exit_handlers)
      cleanup
      return unless handle_exit?(no_exit_handlers)
      # TODO: finalize object and clean up container
      trap!
    end

    def handle_exit?(no_exit_handlers)
      return false if no_exit_handlers
      root = Docker.info.fetch('DockerRootDir')
      return false if File.basename(root) =~ /\d+\.\d+/ # uid.gid
      true
    end
  end
end
