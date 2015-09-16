require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/baseimage'

class BaseImageTest < TestCase
  def test_name
    i = CI::BaseImage.new('ubuntu', 'wily')
    assert_equal(i.to_s, "pangea/ubuntu:wily")
  end
end
