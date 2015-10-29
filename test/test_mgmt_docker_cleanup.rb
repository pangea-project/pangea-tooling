require 'vcr'
require_relative '../ci-tooling/test/lib/testcase'

class MGMTDockerCleanupTest < TestCase
  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body]
      }
    end

    # Clean up should only clean pangea-testing namespace. Testing itself needs
    # to take care not to clean up images that shouldn't be cleaned though.
    @oldnamespace = CI::PangeaImage.namespace
    @namespace = 'pangea-testing'
    CI::PangeaImage.namespace = @namespace
  end

  def teardown
    CI::PangeaImage.namespace = @oldnamespace
  end

  def test_cleanup_on_new
    omit('This test has no testing mode, it would tinker with live images if' \
         ' there is no test data. This *must* not work on live data!')
    pend('This needs a standalone test. It does not actually have anything to' \
         ' to do with the job test.')
    VCR.use_cassette(__method__) do
      assert_nothing_raised do
        require_relative '../mgmt/docker_cleanup.rb'
      end
    end
  end
end
