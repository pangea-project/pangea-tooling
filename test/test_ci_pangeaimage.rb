require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/pangeaimage'

class PangeaImageTest < TestCase
  def setup
    CI::PangeaImage.namespace = 'pangea-testing'
  end
  def assert_image(flavor, series, image)
    assert_equal("#{CI::PangeaImage.namespace}/#{flavor}:#{series}", image.to_s)
    assert_equal("#{CI::PangeaImage.namespace}/#{flavor}", image.repo)
    assert_equal("#{flavor}", image.flavor)
    assert_equal(series, image.tag)
  end

  def test_name
    flavor = 'ubuntu'
    series = 'wily'
    i = CI::PangeaImage.new(flavor, series)
    assert_image(flavor, series, i)
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
    assert_equal("#{CI::PangeaImage.namespace}/ubuntu:wily", image.to_s)
  end
end
