require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/baseimage'

class BaseImageTest < TestCase
  def teardown
    ENV.delete('TESTING')
  end

  def assert_image(flavor, series, image, testing: ENV.fetch('TESTING', false))
    prefix = testing ? 'pangea-testing' : 'pangea'
    assert_equal("#{prefix}/#{flavor}:#{series}", image.to_s)
    assert_equal("#{prefix}/#{flavor}", image.repo)
    assert_equal(series, image.tag)
  end

  def test_name
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::BaseImage.new(flavor, series)
    assert_image(flavor, series, i)
  end

  def test_testing_env
    ENV['TESTING'] = 'true'
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::BaseImage.new(flavor, series)
    assert_image(flavor, series, i)
    ENV.delete('TESTING')
  end
end
