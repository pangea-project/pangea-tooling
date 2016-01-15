require_relative '../lib/ci/pattern'
require_relative 'lib/testcase'

# Test ci/pattern
class CIPatternTest < TestCase
  def test_match
    assert(CI::Pattern.new('a*').match?('ab'))
    assert(!CI::Pattern.new('a*').match?('ba'))
  end

  def test_spaceship_op
    a = CI::Pattern.new('a*')
    assert_equal(nil, a.<=>('a'))
    assert_equal(-1, a.<=>(CI::Pattern.new('*')))
    assert_equal(0, a.<=>(a))
    assert_equal(1, a.<=>(CI::Pattern.new('ab')))
  end

  def test_equal_op
    a = CI::Pattern.new('a*')
    assert(a == 'a*')
    assert(a != 'b')
    assert(a == CI::Pattern.new('a*'))
  end

  def test_to_s
    assert_equal(CI::Pattern.new('a*').to_s, 'a*')
    assert_equal(CI::Pattern.new('a').to_s, 'a')
    assert_equal(CI::Pattern.new(nil).to_s, '')
  end

  def test_hash_convert
    hash = {
      'a*' => {'x*' => false}
    }
    ph = CI::Pattern.convert_hash(hash, recurse: true)
    assert_equal(1, ph.size)
    assert(ph.flatten.first.is_a?(CI::Pattern))
    assert(ph.flatten.last.flatten.first.is_a?(CI::Pattern))
  end

  def test_sort
    # PatternHash has a convenience sort_by_pattern method that allows sorting
    # the first level of a hash by its pattern (i.e. the key).
    h = {
      'a/*' => 'all_a',
      'a/b' => 'b',
      'z/*' => 'all_z'
    }
    ph = CI::Pattern.convert_hash(h)
    assert_equal(3, ph.size)
    ph = CI::Pattern.filter('a/b', ph)
    assert_equal(2, ph.size)
    ph = CI::Pattern.sort_hash(ph)
    # Random note: first is expected technically but since we only allow
    # Pattern == String to evaulate properly we need to invert the order here.
    assert_equal(ph.keys[0], 'a/b')
    assert_equal(ph.keys[1], 'a/*')
  end

  def test_array_sort
    klass = CI::Pattern
    a = [klass.new('a/*'), klass.new('a/b'), klass.new('z/*')]
    a = klass.filter('a/b', a)
    assert_equal(2, a.size)
    assert_equal(a[0], 'a/*')
    a = a.sort
    assert_equal(a[0], 'a/b')
    assert_equal(a[1], 'a/*')
  end

  def test_include_pattern
    ref = 'abcDEF'
    pattern = CI::IncludePattern.new(ref)
    assert(pattern.match?("yolo#{ref}yolo"))
    assert(pattern.match?("yolo#{ref}"))
    assert(pattern.match?("#{ref}yolo"))
    assert_false(pattern.match?("yolo"))
  end
end
