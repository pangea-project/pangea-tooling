require_relative '../lib/retry'
require_relative 'lib/testcase'

class RetryHelper
  attr_reader :count

  def initialize(max_count: 0, errors: [])
    @max_count = max_count
    @errors = errors
  end

  def count_up
    @count ||= 0
    @count += 1
    fail 'random' unless @count == @max_count
  end

  def error
    @error_at ||= -1
    return if @error_at >= @errors.size - 1
    fail @errors[@error_at += 1].new('error')
  end
end

# Test blocking thread pool.
class RetryTest < TestCase
  def test_times
    times = 5
    helper = RetryHelper.new(max_count: times)
    Retry.retry_it(times: times, silent: true) do
      helper.count_up
    end
    assert_equal(times, helper.count)
  end

  def test_zero_retry
    # On zero retries we want to be called once and only once.
    times = 0
    helper = RetryHelper.new(max_count: times)
    assert_raise RuntimeError do
      Retry.retry_it(times: times, silent: true) do
        helper.count_up
      end
    end
  end

  def test_errors
    errors = [NameError, LoadError]

    helper = RetryHelper.new(errors: errors)
    assert_nothing_raised do
      Retry.retry_it(times: errors.size + 1, errors: errors, silent: true) do
        helper.error
      end
    end

    helper = RetryHelper.new(errors: errors)
    assert_raise do
      Retry.retry_it(times: errors.size + 1, errors: [], silent: true) do
        helper.error
      end
    end
  end

  def test_sleep
    sleep = 1
    times = 2
    helper = RetryHelper.new(max_count: times)
    time_before = Time.new
    Retry.retry_it(times: times, sleep: sleep, silent: true) do
      helper.count_up
    end
    time_now = Time.new
    delta_seconds = time_now - time_before
    # Delta must be between actual sleep time and twice the sleep time.
    assert(delta_seconds >= sleep, 'hasnt slept long enough')
    assert(delta_seconds <= sleep * 2.0, 'has slept too long')
  end
end
