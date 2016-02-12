# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require 'logger'
require 'monitor'
require 'thread'

# Limits concurrent git access to any given host type.
class HostSemaphore
  class Error < RuntimeError; end
  class LockReleaseError < Error; end

  MAX_LOCKS = 5

  attr_reader :locks

  def initialize(logger)
    @log = logger

    @locks = []
    @locks.fill(nil, 0, MAX_LOCKS)

    @mutex = Mutex.new
    @condition = ConditionVariable.new
  end

  def log_locks
    @mutex.synchronize do
      @log.warn "Locks  ---  #{@locks}"
      @log.warn 'Trying to cleanup'
      cleanup_lost_locks
      @log.warn "Locks  ---  #{@locks}"
    end
  end

  def synchronize(pid)
    acquired = false

    until acquired
      @mutex.synchronize do
        cleanup_lost_locks
        acquired = acquire_lock(pid)
        @condition.wait(@mutex) unless acquired
      end
    end
    @log.info "acquired lock for #{pid}"

    yield

    @log.info "releasing lock for #{pid}"
    while acquired
      @mutex.synchronize do
        acquired = release_lock(pid)
        @condition.signal unless acquired
      end
      if acquired
        @log.warn "failed to release lock for #{pid}"
        raise LockReleaseError, "failed to release lock for #{pid}"
      end
    end
  end

  private

  # not synchronized
  def acquire_lock(pid)
    acquired = false
    @locks.collect! do |lock|
      next lock if lock || acquired
      acquired = true
      next pid
    end
    acquired
  end

  # not synchronized
  def release_lock(pid)
    acquired = true
    @locks.collect! do |lock|
      next lock unless lock
      next lock if lock != pid || !acquired
      acquired = false
      next nil
    end
    acquired
  end

  # not synchronized
  def cleanup_lost_locks
    process_lost = false
    @locks.collect! do |lock|
      next lock unless lock
      begin
        Process.kill(0, lock)
        @log.info "    process #{lock} still running"
        next lock
      rescue
        process_lost = true
        @log.warn "    process #{lock} lost"
        next nil
      end
    end
    @condition.broadcast if process_lost
  end
end

# A super semaphore to manage per-host semaphores.
# This operates on a number of hosts defined by HOSTS, each HOST
# gets a semaphore with up to five concurrent slots they can use.
# Additional processes are held until a slot frees up.
class Semaphore
  HOSTS = [:debian, :kde, :neon, nil].freeze

  attr_reader :host_semaphores

  def initialize
    @log = Logger.new(STDOUT)
    disable_logging
    @host_semaphores = {}
    HOSTS.each do |host|
      @host_semaphores[host] = HostSemaphore.new(@log)
    end
  end

  def log_locks
    @host_semaphores.each { |_s, sem| sem.log_locks }
  end

  def enable_logging
    @log.level = Logger::INFO
  end

  def disable_logging
    @log.level = Logger::WARN
  end

  def synchronize(pid, host, &block)
    @log.info "synchronizing #{pid} for #{host || 'unknown_host'}"
    @host_semaphores[host].synchronize(pid, &block)
  end
end
