# Prependable module enabling assert_system use by overriding Kernel.system
module AssertSystem
  module_function

  SETUP_BACKUP = :setup_system
  ASSERT_BACKUP = :__system_orig
  METHOD = :system

  # TestUnit prepend to force alias diversion making #{Kernel.system} noop
  def setup
    Kernel.send(:alias_method, SETUP_BACKUP, METHOD)
    Kernel.send(:define_method, METHOD) { |*_a| }
    super if defined?(super)
  end

  # TestUnit prepend to remove alias diversion making #{Kernel.system} noop
  def teardown
    Kernel.send(:alias_method, METHOD, SETUP_BACKUP)
    Kernel.send(:undef_method, SETUP_BACKUP)
    super if defined?(super)
  end

  # Assert that a specific system call is made. The call itself is not made.
  # @param args [Object] any suitable input of #{Kernel.system} that is expected
  # @param block [Block] this function yields to block to actually run a
  #   piece of code that is expected to cause the system call
  # @return [Object] return value of block
  def assert_system(args, &block)
    assertee = self
    Kernel.send(:alias_method, ASSERT_BACKUP, METHOD)
    Kernel.send(:define_method, METHOD) do |*a|
      if !args.empty? && args[0].is_a?(Array)
        assertee.assert_equal([*args.shift], [*a])
      elsif !args.empty?
        assertee.assert_equal([*args], [*a])
        args.clear
      end
      if assertee.respond_to?(:system_intercept)
        return assertee.system_intercept([*a])
      end
      true
    end
    block.yield
    assert(args.empty?, 'Not all system calls were actually called.' \
                        " Left over: #{args}")
  ensure
    Kernel.send(:alias_method, METHOD, ASSERT_BACKUP)
    Kernel.send(:undef_method, ASSERT_BACKUP)
  end
end
