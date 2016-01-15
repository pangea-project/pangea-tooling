require_relative 'lib/testcase'
require_relative '../lib/queue'

# Test queue
class QueueTest < TestCase
  # We are implying that construction from Array works after we have tested
  # that. Otherwise we'd have to construct the queues manually each time.
  self.test_order = :defined

  def test_new_from_array
    array = %w(a b c d e f)
    queue = Queue.new(array)
    assert_equal(array.size, queue.size)
    assert_equal(array.shift, queue.pop) until queue.empty?
  end

  def test_to_array
    array = %w(a b c d e f)
    queue = Queue.new(array)
    assert_equal(array, queue.to_a)
  end
end
