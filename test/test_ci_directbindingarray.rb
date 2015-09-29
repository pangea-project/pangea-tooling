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
    # This is a string containing colon but isn't a binding map
    path = '/tmp/CI::ContainmentTest20150929-32520-12hjrdo'
    b = CI::DirectBindingArray.to_bindings([path])
    assert_equal(["#{path}:#{path}"], b)

    # This is a string containing colons but is already a binding map because
    # it is symetric.
    path = '/tmp:/tmp:/tmp:/tmp'
    b = CI::DirectBindingArray.to_bindings(["#{path}"])
    assert_equal([path], b)

    # Not symetric but the part after the first colon is an absolute path.
    path = '/tmp:/tmp:/tmp'
    b = CI::DirectBindingArray.to_bindings(["#{path}"])
    assert_equal([path], b)
  end
end
