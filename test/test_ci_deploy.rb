require 'vcr'
require 'fileutils'

require_relative '../ci-tooling/test/lib/testcase'

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
        if ((request.uri.end_with? 'export') && !response.nil?)
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
    FileUtils.cp_r(Dir.glob(data), Dir.pwd)
  end

  def test_deploy_exists
    copy_data
    ENV['HOME'] = Dir.pwd

    VCR.use_cassette(__method__, :erb => true) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def teardown
    ENV['HOME'] = @oldhome
  end
end
