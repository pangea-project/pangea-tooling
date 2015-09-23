require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/baseimage'

class BaseImageTest < TestCase
  def test_name
    i = CI::BaseImage.new('ubuntu', 'wily')
    assert_equal("pangea/ubuntu:wily", i.to_s)
    assert_equal("pangea/ubuntu", i.repo)
    assert_equal("wily", i.tag)
  end

  def test_testing_env
    ENV['TESTING'] = 'true'
    i = CI::BaseImage.new('ubuntu', 'wily')
    assert_equal("pangea-testing/ubuntu:wily", i.to_s)
    assert_equal("pangea-testing/ubuntu", i.repo)
    assert_equal("wily", i.tag)
  end
end
