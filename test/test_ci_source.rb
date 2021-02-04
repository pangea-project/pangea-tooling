require_relative '../lib/ci/source'
require_relative 'lib/testcase'

# Test ci/source
class CISourceTest < TestCase
  def setup
    @hash = { 'name' => 'kcmutils',
              'version' => '2.0',
              'type' => 'quilt',
              'dsc' => 'kcmutils_2.0.dsc' }
  end

  def test_to_json
    s = CI::Source.new
    @hash.each do |key, value|
      s[key.to_sym] = value
    end
    json = s.to_json
    assert_equal(@hash, JSON.parse(json))
  end

  def test_from_json
    s1 = CI::Source.new
    @hash.each do |key, value|
      s1[key.to_sym] = value
    end
    json = JSON.generate(@hash)
    s2 = CI::Source.from_json(json)
    assert_equal(s1, s2)
  end

  def test_compare
    s1 = CI::Source.new
    @hash.each do |key, value|
      s1[key.to_sym] = value
    end

    s2 = CI::Source.new
    @hash.each do |key, value|
      s2[key.to_sym] = value
    end

    assert_equal(s1, s2)
    s2[:version] = '0.0'
    assert_not_equal(s1, s2)
  end
end
