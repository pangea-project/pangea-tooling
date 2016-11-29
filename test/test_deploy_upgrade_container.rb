require 'vcr'

require_relative '../lib/ci/containment.rb'
require_relative '../ci-tooling/test/lib/testcase'

require 'mocha/test_unit'

Excon.defaults[:read_timeout] = 4 * 60 * 60 # 4 hours.

class DeployUpgradeTest < TestCase
  self.file = __FILE__

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

  def cleanup_image
    return unless Docker::Image.exist?(@image)
    puts "Cleaning up image #{@image}"
    image = Docker::Image.get(@image)
    image.delete(force: true, noprune: true)
  rescue Docker::Error::NotFoundError, Excon::Errors::SocketError
  end

  def create_container
    puts "Creating new base image #{@image}"
    Docker::Image.create(fromImage: 'ubuntu:vivid').tag(repo: @repo,
                                                        tag: 'latest')
  end
  # :nocov:

  def setup
    # Disable attaching as on failure attaching can happen too late or not
    # at all as it depends on thread execution order.
    # This can cause falky tests and is not relevant to the test outcome for
    # any test.
    CI::Containment.no_attach = true

    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body]
      }
      # ERB PWD
      config.filter_sensitive_data('<%= Dir.pwd %>') { Dir.pwd }
    end

    @repo = self.class.to_s.downcase
    @image = "#{@repo}:latest"

    @job_name = @repo.tr(':', '_')
    @tooling_path = File.expand_path("#{__dir__}/../")
    @binds = ["#{Dir.pwd}:/tooling-pending"]
    FileUtils.cp_r(Dir.glob("#{@tooling_path}/deploy_upgrade_container.sh"),
                   Dir.pwd)
    FileUtils.cp_r("#{@datadir}/deploy_in_container.sh", Dir.pwd)

    # Fake info call for consistency
    Docker.stubs(:info).returns('DockerRootDir' => '/var/lib/docker')
    Docker.stubs(:version).returns('ApiVersion' => '1.24', 'Version' => '1.12.3')
  end

  def teardown
    VCR.turned_off do
      cleanup_container
    end
    CI::EphemeralContainer.safety_sleep = 5
  end

  def vcr_it(meth, **kwords)
    defaults = {
      erb: true
    }
    VCR.use_cassette(meth, defaults.merge(kwords)) do |cassette|
      if cassette.recording?
        VCR.eject_cassette
        VCR.turned_off do
          cleanup_container
          cleanup_image
          create_container
        end
        VCR.insert_cassette(cassette.name)
      else
        CI::EphemeralContainer.safety_sleep = 0
      end
      yield cassette
    end
  end

  def test_no_argv0
    vcr_it(__method__) do
      c = CI::Containment.new(@job_name, image: @image, binds: @binds)
      cmd = ['sh', '/tooling-pending/deploy_upgrade_container.sh']
      ret = c.run(Cmd: cmd)
      assert_equal(1, ret)
    end
  end

  def test_no_argv1
    vcr_it(__method__) do
      c = CI::Containment.new(@job_name, image: @image, binds: @binds)
      cmd = ['sh', '/tooling-pending/deploy_upgrade_container.sh',
             'vivid']
      ret = c.run(Cmd: cmd)
      assert_equal(1, ret)
    end
  end

  def test_success
    vcr_it(__method__) do
      c = CI::Containment.new(@job_name, image: @image, binds: @binds)
      cmd = ['sh', '/tooling-pending/deploy_upgrade_container.sh',
             'vivid', 'wily']
      ret = c.run(Cmd: cmd)
      assert_equal(0, ret)
      # The script has testing capability built in since we have no proper
      # provisioning to inspect containments post-run in any sort of reasonable
      # way to make assertations. This is a bit of a tricky thing to get right
      # so for the time being inside-testing will have to do.
    end
  end
end
