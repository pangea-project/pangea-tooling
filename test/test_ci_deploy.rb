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

      # Ignore the events request from docker, since the cassete apparently
      # does not record them.
      config.ignore_request do |request|
        request.uri.end_with? 'events'
      end

      # VCR records the binary tar image over the socket, so instead of actually
      # writing out the binary tar, replace it with a known string.
      config.after_http_request do |request, response|
        response.body = 'BINARY_IMAGE_EXPORTED' if request.uri.end_with? 'export'
      end
    end

    @oldhome = ENV.fetch('HOME')
  end

  def test_deploy
    ENV['HOME'] = '/tmp/pangea-tooling-testing'
    FileUtils.mkdir_p("#{ENV.fetch('HOME')}/tooling-pending/")
    File.open("#{ENV.fetch('HOME')}/tooling-pending/deploy_in_container.sh", 'w+') do |f|
      f.write("#!/bin/bash\n")
      f.write("echo Test\n")
      f.write("exit 0\n")
    end
    File.chmod(0777, "#{ENV.fetch('HOME')}/tooling-pending/deploy_in_container.sh")

    VCR.use_cassette(__method__) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def teardown
    ENV['HOME'] = @oldhome
  end
end
