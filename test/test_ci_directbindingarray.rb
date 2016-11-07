require_relative '../lib/ci/directbindingarray'
require_relative '../ci-tooling/test/lib/testcase'

class DirectBindingArrayTest < TestCase
  def test_to_volumes
    v = CI::DirectBindingArray.to_volumes(['/', '/tmp'])
    assert_equal({ '/' => {}, '/tmp' => {} }, v)
  end

  def test_to_bindings
    b = CI::DirectBindingArray.to_bindings(['/', '/tmp'])
    assert_equal(%w(/:/ /tmp:/tmp), b)
  end

  def test_to_volumes_mixed_format
    v = CI::DirectBindingArray.to_volumes(['/', '/tmp:/tmp'])
    assert_equal({ '/' => {}, '/tmp' => {} }, v)
  end

  def test_to_bindings_mixed_fromat
    b = CI::DirectBindingArray.to_bindings(['/', '/tmp:/tmp'])
    assert_equal(%w(/:/ /tmp:/tmp), b)
  end

  def test_to_bindings_colons
    path = '/tmp/CI::ContainmentTest20150929-32520-12hjrdo'
    assert_raise do
      CI::DirectBindingArray.to_bindings([path])
    end

    assert_raise do
      CI::DirectBindingArray.to_bindings([path])
    end

    assert_raise do
      path = '/tmp:/tmp:/tmp:/tmp'
      CI::DirectBindingArray.to_bindings(["#{path}"])
    end

    assert_raise do
      path = '/tmp:/tmp:/tmp'
      CI::DirectBindingArray.to_bindings(["#{path}"])
    end
  end

  def test_not_a_array
    assert_raise CI::DirectBindingArray::InvalidBindingType do
      CI::DirectBindingArray.to_bindings("kitten")
    end
  end
end
