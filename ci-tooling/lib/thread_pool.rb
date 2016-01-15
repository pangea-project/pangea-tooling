require 'thwait'

require_relative 'queue'

# Simple thread pool implementation. Pass a block to run and it runs it in a
# pool.
# Note that the block code should be thread safe...
module BlockingThreadPool
  # Runs the passed block in a pool. This function blocks until all threads are
  # done.
  # @param count the thread count to use for the pool
  def self.run(count = 16, abort_on_exception: true, &block)
    threads = []
    count.times do
      threads << Thread.new(nil) do
        Thread.current.abort_on_exception = abort_on_exception
        block.call
      end
    end
    ThreadsWait.all_waits(threads)
  end
end
