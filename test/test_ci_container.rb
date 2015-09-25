require 'vcr'

require_relative '../lib/ci/container.rb'
require_relative '../ci-tooling/test/lib/testcase'

class DirectBindingArrayTest < TestCase
  def test_to_volumes
    v = CI::Container::DirectBindingArray.to_volumes(['/', '/tmp'])
    assert_equal({ '/' => {}, '/tmp' => {} }, v)
  end

  def test_to_bindings
    b = CI::Container::DirectBindingArray.to_bindings(['/', '/tmp'])
    assert_equal(%w(/:/ /tmp:/tmp), b)
  end

  def test_to_volumes_mixed_format
    v = CI::Container::DirectBindingArray.to_volumes(['/', '/tmp:/tmp'])
    assert_equal({ '/' => {}, '/tmp' => {} }, v)
  end

  def test_to_bindings_mixed_fromat
    b = CI::Container::DirectBindingArray.to_bindings(['/', '/tmp:/tmp'])
    assert_equal(%w(/:/ /tmp:/tmp), b)
  end
end

# The majority of functionality is covered through containment.
# Only test what remains here.
class ContainerTest < TestCase
  # :nocov:
  def cleanup_container
    # Make sure the default container name isn't used, it can screw up
    # the vcr data.
    c = Docker::Container.get(@job_name)
    c.stop
    c.kill!
    c.remove
  rescue Docker::Error::NotFoundError, Excon::Errors::SocketError
  end
  # :nocov:

  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body]
      }
    end

    # Chdir to root, as Containment will set the working dir to PWD and this
    # is slightly unwanted for tmpdir tests.
    Dir.chdir('/')

    @job_name = self.class.to_s
    @image = 'ubuntu:15.04'
    VCR.turned_off { cleanup_container }
  end

  def teardown
    VCR.turned_off { cleanup_container }
  end

  def test_exist
    VCR.use_cassette(__method__) do
      assert(!CI::Container.exist?(@job_name))
      CI::Container.create(Image: @image, name: @job_name)
      assert(CI::Container.exist?(@job_name))
    end
  end
end
