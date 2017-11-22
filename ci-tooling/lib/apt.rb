# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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
require 'open-uri'
require 'tty/command'

require_relative 'apt/key'
require_relative 'apt/repository'

# Cow powers!
#
# This module provides access to apt by catching method missing and passing the
# method call on to apt.
# So calling Apt.install will call 'apt install'. Also convenient default
# arguments will be injected into the call to give debugging and so forth.
#
# Commands that contain a hyphen are spelt with an underscore due to ruby
# langauge restrictions. All underscores are automatically replaced with hyphens
# upon method handling. To bypass this the Abstrapt.run method needs to be used
# directly.
module Apt
  def self.method_missing(name, *caller_args)
    Abstrapt.run('apt-get', name.to_s.tr('_', '-'), *caller_args)
  end

  # More cow powers!
  # Calls apt-get instead of apt. Otherwise the same as {Apt}
  module Get
    def self.method_missing(name, *caller_args)
      Abstrapt.run('apt-get', name.to_s.tr('_', '-'), *caller_args)
    end
  end

  # Abstract base for apt execution.
  module Abstrapt
    module ClassMethods
      def run(cmd, operation, *caller_args)
        @log ||= Logger.new(STDOUT)
        auto_update unless operation == 'update'
        run_internal(cmd, operation, *caller_args)
      end

      def run_internal(cmd, operation, *caller_args)
        args = run_internal_args(operation, *caller_args)
        @log.warn "APT run (#{cmd}, #{args})"
        system(cmd, *args)
      end

      def run_internal_args(operation, *caller_args)
        injection_args = []
        caller_args.delete_if do |arg|
          next false unless arg.is_a?(Hash)
          next false unless arg.key?(:args)
          injection_args = [*(arg[:args])]
          true
        end
        args = [] + default_args + injection_args
        args << operation
        # Flatten args. system doesn't support nested arrays anyway, so
        # flattening is probably what the caller had in mind
        # (e.g. install(['a', 'b']))
        args + [*caller_args].flatten
      end

      def auto_update
        return if @auto_update_disabled
        return unless @last_update.nil? || (Time.now - @last_update) >= (5 * 60)
        return unless Apt.update
        @last_update = Time.now
      end

      # @return [Array<String>] default arguments to inject into apt call
      def default_args
        @default_args if defined?(@default_args)
        @default_args = []
        @default_args << '-y'
        @default_args << '-o' << 'APT::Get::force-yes=true'
        @default_args << '-o' << 'Debug::pkgProblemResolver=true'
        @default_args << '-q' # no progress!
        @default_args
      end

      def reset
        @last_update = nil
        @auto_update_disabled = false
      end

      def disable_auto_update
        @auto_update_disabled = true
        ret = yield
        @auto_update_disabled = false
        ret
      end
    end

    extend ClassMethods

    def self.included(othermod)
      othermod.extend(ClassMethods)
    end
  end

  # apt-cache wrapper
  module Cache
    include Abstrapt

    def self.exist?(pkg)
      show(pkg, [:out, :err] => '/dev/null')
    end

    def self.method_missing(name, *caller_args)
      run('apt-cache', name.to_s.tr('_', '-'), *caller_args)
    end

    def self.default_args
      # Can't use apt-get default arguments. They aren't compatible.
      @default_args = %w[-q]
    end
  end

  # apt-mark wrapper
  module Mark
    module_function

    BINARY = 'apt-mark'

    AUTO = :auto
    MANUAL = :manual
    HOLD = :hold

    class UnknownStateError < StandardError; end

    # NOTE: should more methods be needed it may be worthwhile to put Cmd.new
    #   into its own wrapper method which can be stubbed in tests. That way
    #   the code would be detached from the internal fact that TTY::cmd is used.

    def state(pkg)
      cmd = TTY::Command.new(printer: :pretty)
      out, = cmd.run(BINARY, 'showauto', pkg)
      return AUTO if out.strip == pkg
      out, = cmd.run(BINARY, 'showmanual', pkg)
      return MANUAL if out.strip == pkg
      out, = cmd.run(BINARY, 'showhold', pkg)
      return HOLD if out.strip == pkg
      warn "#{pkg} has an unknown mark state :O"
      nil
      # FIXME: we currently do not raise here because the cmake and qml dep
      #   verifier are broken and do not always use the right version to install
      #   a dep. This happens when foo=1.0 is the source but a binary gets
      #   mangled to be bar=4:1.0 (i.e. with epoch). This is not reflected in
      #   the changes file so the dep verifiers do not know about this and
      #   attempt to install the wrong version. When then trying to get the
      #   mark state things implode. This needs smarter version logic for
      #   the dep verfiiers before we can make unknown marks fatal again.
    end

    def mark(pkg, state)
      TTY::Command.new.run(BINARY, state.to_s, pkg)
    end

    def tmpmark(pkg, state)
      old_state = state(pkg)
      mark(pkg, state)
      yield
    ensure
      mark(pkg, old_state) if old_state
    end
  end
end
