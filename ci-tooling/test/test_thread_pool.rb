require_relative '../lib/thread_pool'
require_relative 'lib/testcase'

# Test blocking thread pool.
class BlockingThreadPoolTest < TestCase
  def test_thread_pool
    queue = Queue.new
    32.times { |i| queue << i }
    BlockingThreadPool.run do
      until queue.empty?
        i = queue.pop(true)
        File.write(i.to_s, '')
      end
    end
    32.times do |i|
      assert(File.exist?(i.to_s), "File #{i} was not created")
    end
  end

  def test_thread_pool_aborting
    errors = Queue.new
    BlockingThreadPool.run(1) do
      errors << 'Thread not aborting' unless Thread.current.abort_on_exception
    end

    BlockingThreadPool.run(1, abort_on_exception: false) do
      errors << 'Thread aborting' if Thread.current.abort_on_exception
    end

    assert(errors.empty?, 'abortion settings do not match expectation')
  end

  def test_thread_pool_count
    # If the queue count is equal to the thread count then all files should
    # be created without additional looping inside the threads.
    queue = Queue.new
    4.times { |i| queue << i }
    BlockingThreadPool.run(4) do
      i = queue.pop(true)
      File.write(i.to_s, '')
    end
    4.times do |i|
      assert(File.exist?(i.to_s), "File #{i} was not created")
    end
  end
end
