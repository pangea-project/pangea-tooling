require_relative 'lib/testcase'

class Prop < TestCase
end

# Test TestCase class for everything we currently do not actively use as well
# as failure scenarios.
class TestTestCase < Test::Unit::TestCase
  # Prop is configured in order, so tests depend on their definition order.
  self.test_order = :defined

  def test_file
    assert_nothing_raised do
      Prop.send(:file=, 'abc')
    end
    assert_equal('abc', Prop.file)
  end

  def test_data_lookup_fail
    assert_raise RuntimeError do
      Prop.new(nil).data
    end
  end
end
