require_relative 'lib/testcase'

require_relative '../lib/deprecate'

class DeprecateTest < TestCase
  class Dummy
    extend Deprecate

    def a
      variable_deprecation('variable', 'replacement')
    end
  end

  def test_deprecate_var
    assert_include(Deprecate.ancestors, Gem::Deprecate)
    dummy = Dummy.new
    assert(dummy.class.is_a?(Deprecate))
    assert_include(dummy.class.ancestors, Deprecate::InstanceMethods)
    dummy.send :variable_deprecation, 'variable', 'replacement'
    dummy.a
  end
end
