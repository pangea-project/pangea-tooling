# Prependable module enabling assert_system use by overriding Kernel.`
module AssertBacktick
  module_function

  SETUP_BACKUP = :setup_backtick
  ASSERT_BACKUP = :__backtick_orig
  METHOD = :`

  # TestUnit prepend to force alias diversion making #{Kernel.`} noop
  def setup
    Kernel.send(:alias_method, SETUP_BACKUP, METHOD)
    Kernel.send(:define_method, METHOD) { |*_a| }
    super if defined?(super)
  end

  # TestUnit prepend to remove alias diversion making #{Kernel.`} noop
  def teardown
    Kernel.send(:alias_method, METHOD, SETUP_BACKUP)
    Kernel.send(:undef_method, SETUP_BACKUP)
    super if defined?(super)
  end

  # Assert that a specific system call is made. The call itself is not made.
  # @param args [Object] any suitable input of #{Kernel.`} that is expected
  # @param block [Block] this function yields to block to actually run a
  #   piece of code that is expected to cause the system call
  # @return [Object] return value of block
  def assert_backtick(args, &block)
    assertee = self
    Kernel.send(:alias_method, ASSERT_BACKUP, METHOD)
    Kernel.send(:define_method, METHOD) do |*a|
      if !args.empty? && args[0].is_a?(Array)
        assertee.assert_equal([*args.shift], [*a])
      elsif !args.empty?
        assertee.assert_equal([*args], [*a])
        args.clear
      end
      if assertee.respond_to?(:backtick_intercept)
        return assertee.backtick_intercept([*a])
      end
      ''
    end
    block.yield
    assert(args.empty?, 'Not all system calls were actually called.' \
                        " Left over: #{args}")
  ensure
    Kernel.send(:alias_method, METHOD, ASSERT_BACKUP)
    Kernel.send(:undef_method, ASSERT_BACKUP)
  end
end
