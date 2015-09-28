require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/pangeaimage'

class PangeaImageTest < TestCase
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
    i = CI::PangeaImage.new(flavor, series)
    assert_image(flavor, series, i)
  end

  def test_testing_env
    ENV['TESTING'] = 'true'
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::PangeaImage.new(flavor, series)
    assert_image(flavor, series, i)
    ENV.delete('TESTING')
  end

  def test_to_str
    # Coercion into string
    assert_nothing_raised TypeError do
      '' + CI::PangeaImage.new('flavor', 'series')
    end
  end

  def test_symbol_flavor
    flavor = :ubuntu
    series = 'wily'
    image = CI::PangeaImage.new(flavor, series)
    # Do not use assert_image here as we need to verify coercion from
    # :ubuntu to 'ubuntu' works as expected.
    # assert_image in fact relies on it.
    assert_equal('pangea/ubuntu:wily', image.to_s)
  end
end
