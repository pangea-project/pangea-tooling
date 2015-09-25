require 'vcr'
require 'fileutils'
require 'docker'

require_relative '../lib/ci/baseimage'
require_relative '../ci-tooling/test/lib/testcase'
require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/dpkg'

class DeployTest < TestCase
  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body]
      }

      # VCR records the binary tar image over the socket, so instead of actually
      # writing out the binary tar, replace it with a known string.
      config.after_http_request do |request, response|
        if ((request.uri.end_with? 'export'))

          # Weird docker bug where the response is nil
          if response.nil?
            require 'pp'
            pp "Oh noes, response was nil for ", request
            response = VCR::Response.new
          end

          response.body = 'BINARY_IMAGE_EXPORTED'
        end
      end
    end

    # Make sure we inject the TESTING env var so that docker.rb does not enable
    # event logging
    ENV['TESTING'] = 'true'

    @oldhome = ENV.fetch('HOME')
  end

  def copy_data
    FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
  end

  def create_base(flavor, version)
    b = CI::BaseImage.new(flavor, version)
    # create base
    unless Docker::Image.exist?(b.to_s)
      docker_image = "#{flavor}:#{version}"
      docker_image = "armbuild/#{flavor}:#{version}" if DPKG::HOST_ARCH == 'armhf'
      Docker::Image.create(fromImage: docker_image).tag(repo: b.repo, tag: b.tag)
    end
  end

  def remove_base(flavor, version)
    b = CI::BaseImage.new(flavor, version)
    # create base
    if Docker::Image.exist?(b.to_s)
      image = Docker::Image.get(b.to_s)
      image.delete(:force => true)
    end
  end

  def test_deploy_exists
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      KCI.series.keys.each do |k|
        create_base('ubuntu', k)
      end

      DCI.series.keys.each do |k|
        create_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, :erb => true) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def test_deploy_new
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      KCI.series.keys.each do |k|
        remove_base('ubuntu', k)
      end

      DCI.series.keys.each do |k|
        remove_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, :erb => true) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def teardown
    ENV['HOME'] = @oldhome
    ENV.delete('TESTING')
  end
end
