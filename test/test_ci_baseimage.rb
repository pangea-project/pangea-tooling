require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/baseimage'

class BaseImageTest < TestCase
  def teardown
    ENV.delete('TESTING')
  end

  def test_name
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::BaseImage.new(flavor, series)
    assert_equal("pangea/#{flavor}:#{series}", i.to_s)
    assert_equal("pangea/#{flavor}", i.repo)
    assert_equal(series, i.tag)
  end

  def test_testing_env
    ENV['TESTING'] = 'true'
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::BaseImage.new(flavor, serise)
    assert_equal("pangea-testing/#{flavor}:#{series}", i.to_s)
    assert_equal("pangea-testing/#{flavor}", i.repo)
    assert_equal(series, i.tag)
    ENV.delete('TESTING')
  end
end
