require_relative '../ci-tooling/test/lib/testcase'
require_relative '../git-monitor/lib/semaphore'

class GitSemaphoreTest < TestCase
  def test_init
    s = Semaphore.new
    assert_equal(s.class::HOSTS, s.host_semaphores.keys)
    s.host_semaphores.each do |host, sem|
      assert_equal(sem.class::MAX_LOCKS, sem.locks.size,
                   "Size of locks for host #{host} incorrect.")
    end
  end

  def test_sync
    s = Semaphore.new
    host = :debian
    s.synchronize(1, host) do
      assert_include(s.host_semaphores[host].locks, 1)
    end
    assert_not_include(s.host_semaphores[host].locks, 1)
  end

  def test_cleanup
    s = Semaphore.new
    host = :debian
    # We are going to release the lock while the block is still running
    # this is expected to raise a release error on account of us not having
    # terminated properly.
    assert_raise HostSemaphore::LockReleaseError do
      s.synchronize(1, host) do
        # Attempt to sync again. This should now kill our previous lock.
        s.synchronize(2, host) do
          assert_not_include(s.host_semaphores[host].locks, 1)
          assert_include(s.host_semaphores[host].locks, 2)
        end
        assert_not_include(s.host_semaphores[host].locks, 1)
        assert_not_include(s.host_semaphores[host].locks, 2)
      end
    end
    # This assert applies after the release has raised.
    assert_not_include(s.host_semaphores[host].locks, 1)
  end

  def test_logging
    log_path = "#{Dir.pwd}/log"
    logger = Logger.new(log_path)

    s = Semaphore.new
    s.instance_variable_set(:@log, logger)
    s.host_semaphores.each do |_, sem|
      sem.instance_variable_set(:@log, logger)
    end
    s.enable_logging
    s.log_locks

    assert(File.exist?(log_path))
    assert_not_equal('', File.read(log_path))
    assert(File.read(log_path).lines.size > s.host_semaphores.size)
  end

  def assert_single_lock(semaphore, pid, host)
    s = semaphore
    s.synchronize(pid, host) do
      locks = s.host_semaphores[host].locks.dup
      assert_equal(s.host_semaphores[host].class::MAX_LOCKS, locks.size)
      locks.delete_if(&:nil?)
      assert_equal(1, locks.size)
      assert_equal(locks[0], pid)
      yield if block_given?
    end
  end

  def test_host_separation
    # Each host is supposed to have their own lock pool as it were.
    s = Semaphore.new
    assert_single_lock(s, 1, :debian) do
      assert_single_lock(s, 2, :kde)
    end
  end
end
