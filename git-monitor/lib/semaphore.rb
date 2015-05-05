require 'logger'
require 'monitor'
require 'thread'

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
        fail LockReleaseError, "failed to release lock for #{pid}"
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
        # Process methods cannot be overridden for some reason I cannot quite
        # apprehend. So unfortunatley we cannot test the following.
        # Attempted to alias, redefine, direct call, call via send, call via
        # __send__ all to noavail either it uses the actual kill or even when
        # using a new method it will raise the method being undefined.
        # :nocov:
        @log.info "    process #{lock} still running"
        next lock
        # :nocov:
      rescue
        process_lost = true
        @log.warn "    process #{lock} lost"
        next nil
      end
    end
    @condition.broadcast if process_lost
  end
end

class Semaphore
  HOSTS = [:debian, :kde, nil]

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
