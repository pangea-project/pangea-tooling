require 'vcr'

require_relative '../lib/ci/container.rb'
require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'

# The majority of functionality is covered through containment.
# Only test what remains here.
class ContainerTest < TestCase
  # :nocov:
  def cleanup_container
    # Make sure the default container name isn't used, it can screw up
    # the vcr data.
    c = Docker::Container.get(@job_name)
    c.stop
    c.kill! if c.json.fetch['State'].fetch['Running']
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

    @job_name = self.class.to_s
    @image = 'ubuntu:15.04'
    VCR.turned_off do
      cleanup_container
    end
  end

  def teardown
    VCR.turned_off { cleanup_container }
  end

  # FIXME: Make vcr_it a common method for tests
  def vcr_it(meth, **kwords)
    VCR.use_cassette(meth, kwords) do |cassette|
      if cassette.recording?
        VCR.turned_off do
          Docker::Image.create(fromImage: @image)
        end
      else
        CI::EphemeralContainer.safety_sleep = 0
      end
      yield cassette
    end
  end

  def test_exist
    vcr_it(__method__) do
      assert(!CI::Container.exist?(@job_name))
      CI::Container.create(Image: @image, name: @job_name)
      assert(CI::Container.exist?(@job_name))
    end
  end

  ### Compatibility tests! DirectBindingArray used to live in Container.

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

  def test_to_bindings_colons
    # This is a string containing colon but isn't a binding map
    path = '/tmp/CI::ContainmentTest20150929-32520-12hjrdo'
    assert_raise do
      CI::Container::DirectBindingArray.to_bindings([path])
    end

    # This is a string containing colons but is already a binding map because
    # it is symetric.
    path = '/tmp:/tmp:/tmp:/tmp'
    assert_raise do
      CI::Container::DirectBindingArray.to_bindings([path.to_s])
    end

    # Not symetric but the part after the first colon is an absolute path.
    path = '/tmp:/tmp:/tmp'
    assert_raise do
      CI::Container::DirectBindingArray.to_bindings([path.to_s])
    end
  end

  def test_privileged_implies_usernsmodehost
    fake_container = mock('fake_container')
    Docker::Container.expects(:create)
                     .with do |*x|
                       x = x.shift
                       x[:Privileged] == true && x[:UsernsMode] == 'host'
                     end.returns(fake_container)
    CI::Container.create(Privileged: true)
  end
end
