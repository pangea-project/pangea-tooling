require 'vcr'

require_relative '../kci/docker/containment.rb'
require_relative '../ci-tooling/test/lib/testcase'

class BuildTest < TestCase
  self.file = __FILE__

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
  end

  def test_init
    job_name = 'vivid_unstable_test'
    image = 'vivid_unstable'
    binds = [Dir.pwd, 'a:a']
    bindified_binds = ["#{Dir.pwd}:#{Dir.pwd}", 'a:a']
    volumes = {Dir.pwd => {}, 'a' => {}}
    VCR.use_cassette(__method__) do
      c = Containment.new(job_name, image: image, binds: binds)
      assert_equal(job_name, c.name)
      assert_equal(image, c.image)
      assert_equal(bindified_binds, c.binds)
      assert_equal(volumes, c.volumes)
    end
  end

  def test_run
    job_name = 'vivid_unstable_test'
    image = 'jenkins/vivid_unstable'
    binds = []
    VCR.use_cassette(__method__) do
      c = Containment.new(job_name, image: image, binds: binds)
      ret = c.run(Cmd: ['bash', '-c', "echo #{job_name}"])
      assert_equal(0, ret)

      ret = c.run(Cmd: ['garbage_fail'])
      assert_not_equal(0, ret)
    end
  end

  def test_cleanup
    job_name = 'vivid_unstable_test'
    image = 'jenkins/vivid_unstable'
    VCR.use_cassette(__method__) do
      Docker::Container.create(Image: image).tap { |c| c.rename(job_name) }
      Containment.new(job_name, image: image, binds: [])
      assert_raise Docker::Error::NotFoundError do
        Docker::Container.get(job_name)
      end
    end
  end
end
