# Helps with retrying an exception throwing code.
module Retry
  module_function

  # Retry given block.
  # @param tries [Integer] amount of tries
  # @param errors [Array<Object>] errors to rescue
  # @param sleep [Integer, nil] seconds to sleep between tries
  # @param name [String, 'unknown'] name of the action (debug when not silent)
  # @yield yields to block which needs retrying
  def retry_it(times: 1, errors: [StandardError], sleep: nil, silent: false,
               name: 'unknown')
    yield
  rescue *errors => e
    raise e if (times -= 1) == 0
    print "Error on retry_it(#{name}) :: #{e}\n" unless silent
    Kernel.sleep(sleep) if sleep
    retry
  end
end
