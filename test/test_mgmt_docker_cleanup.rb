require 'vcr'

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/docker/cleanup'

class MGMTDockerCleanupTest < TestCase
  # :nocov:
  def create_image
    assert_image(Docker::Image.create(fromImage: 'ubuntu:vivid'))
  end
  # :nocov:

  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body],
        tag: :erb_pwd
      }

      # The PWD is used as home and as such it appears in the interactions.
      # Filter it into a ERB expression we can play back.
      config.filter_sensitive_data('<%= Dir.pwd %>', :erb_pwd) { Dir.pwd }
    end
  end

  def assert_image(image)
    assert_not_nil(image)
    assert_is_a(image, Docker::Image)
    image
  end

  def disable_body_match
    VCR.configure do |c|
      begin
        body = c.default_cassette_options[:match_requests_on].delete(:body)
        yield
      ensure
        c.default_cassette_options[:match_requests_on] << :body if body
      end
    end
  end

  def derive_image(image)
    File.write('yolo', '')
    # Nobody knows why but that bit of API uses strings Oo
    # insert_local dockerfiles off of our baseimage and creates
    i = nil
    disable_body_match do
      i = image.insert_local('localPath' => "#{Dir.pwd}/yolo",
                             'outputPath' => '/yolo')
    end
    assert_image(i)
    i
  end

  # This test presently relies on docker not screwing up and deleting
  # images that do not dangle. Should we change to our own implementation
  # we need substantially more testing to make sure we don't screw up...
  def test_cleanup_images
    VCR.use_cassette(__method__, erb: true) do
      image = create_image # standard image
      assert_not_nil(image)
      assert_is_a(image, Docker::Image)
      File.write('yolo', '')
      # Nobody knows why but that bit of API uses strings Oo
      # insert_local dockerfiles off of our baseimage and creates
      dangling_image = image.insert_local('localPath' => "#{Dir.pwd}/yolo",
                                          'outputPath' => '/yolo')
      assert_not_nil(image)
      assert_is_a(image, Docker::Image)
      Docker::Cleanup.images
      assert(!Docker::Image.exist?(dangling_image.id))
    end
  end
end
