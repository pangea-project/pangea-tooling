require 'vcr'

require_relative '../lib/ci/containment.rb'
require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/pangeaimage'

require 'mocha/test_unit'

module CI
  class BindsPassed < RuntimeError; end
  class ContainmentTest < TestCase
    self.file = __FILE__
    self.test_order = :alphabetic # There's a test_ZZZ to be run at end

    # :nocov:
    def cleanup_container
      # Make sure the default container name isn't used, it can screw up
      # the vcr data.
      c = Docker::Container.get(@job_name)
      c.stop
      c.kill! if c.json.fetch('State').fetch('Running')
      c.remove
    rescue Docker::Error::NotFoundError, Excon::Errors::SocketError
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
        config.filter_sensitive_data('<%= Dir.pwd %>', :erb_pwd) { Dir.pwd }
      end
      # Chdir to root, as Containment will set the working dir to PWD and this
      # is slightly unwanted for tmpdir tests.
      Dir.chdir('/')

      @job_name = 'vivid_unstable_test'
      @image = PangeaImage.new('ubuntu', 'vivid')

      VCR.turned_off { cleanup_container }
      Containment::TRAP_SIGNALS.each { |s| Signal.trap(s, nil) }

      # Fake info call for consistency
      Docker.stubs(:info).returns('DockerRootDir' => '/var/lib/docker')
    end

    def teardown
      VCR.turned_off { cleanup_container }
      CI::EphemeralContainer.safety_sleep = 5
    end

    def assert_handler_set(signal)
      message = build_message(nil, 'Signal <?> is nil or DEFAULT.', signal)
      handler = Signal.trap(signal, nil)
      assert_block message do
        !(handler.nil? || handler == 'DEFAULT')
      end
    end

    def assert_handler_not_set(signal)
      message = build_message(nil, 'Signal <?> is not nil or DEFAULT.', signal)
      handler = Signal.trap(signal, nil)
      assert_block message do
        handler.nil? || handler == 'DEFAULT'
      end
    end

    def vcr_it(meth, **kwords)
      VCR.use_cassette(meth, kwords) do |cassette|
        if cassette.recording?
          VCR.turned_off do
            image = Docker::Image.create(fromImage: 'ubuntu:vivid')
            image.tag(repo: @image.repo, tag: @image.tag) unless Docker::Image.exist? @image.to_s
          end
        else
          CI::EphemeralContainer.safety_sleep = 0
        end
        yield cassette
      end
    end

    # This test is order dependent!
    # Traps musts be nil first to properly assert that the containment set
    # new traps. But they won't be nil if another containment ran previously.
    def test_AAA_trap_its
      sigs = Containment::TRAP_SIGNALS
      sigs.each { |sig| assert_handler_not_set(sig) }
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image)
        assert_not_nil(c.send(:chown_handler))
      end
      sigs.each { |sig| assert_handler_set(sig) }
    end

    def test_AAA_trap_its_privileged_and_trap_run_indicates_no_handlers
      sigs = Containment::TRAP_SIGNALS
      sigs.each { |sig| assert_handler_not_set(sig) }
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, privileged: true)
        assert_false(c.trap_run)
      end
      # Make sure trap_run *actually* is false iff the handlers were not set.
      sigs.each { |sig| assert_handler_not_set(sig) }
    end

    def test_BBB_chown_handle_bindings_in_docker_notation
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: ['/asd:/asd'])
        handler = c.send(:chown_handler)
        stub_containment = mock('containment')
        stub_containment.stubs(:run).returns(true)
        Containment.expects(:new).never
        Containment.expects(:new).with do |*_, **kwords|
          assert_include(kwords, :binds)
          assert_equal(kwords[:binds], ['/asd'])
          true
        end.returns(stub_containment)
        handler.call
      end
    end

    def test_init
      binds = [Dir.pwd, 'a:a']
      priv = true
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: binds,
                                       privileged: priv)
        assert_equal(@job_name, c.name)
        assert_equal(@image, c.image)
        assert_equal(binds, c.binds)
        assert_equal(priv, c.privileged)
      end
    end

    def test_run
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: [])
        ret = c.run(Cmd: ['bash', '-c', "echo #{@job_name}"])
        assert_equal(0, ret)
        ret = c.run(Cmd: ['bash', '-c', 'exit 1'])
        assert_equal(1, ret)
      end
    end

    def test_check_priv
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: [], privileged: true)
        ret = c.run(Cmd: ['bash', '-c', 'if [ ! -e /dev/tty0 ]; then exit 1; fi'])
        assert_equal(0, ret)
      end
    end

    def test_check_unpriv
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: [], privileged: false)
        ret = c.run(Cmd: ['bash', '-c', 'if [ ! -e /dev/tty0 ]; then exit 1; fi'])
        assert_equal(1, ret)
      end
    end

    def test_run_fail
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: [])
        ret = c.run(Cmd: ['garbage_fail'])
        assert_not_equal(0, ret)
      end
    end

    def test_run_env
      binds = []
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: binds)
        ENV['DIST'] = 'dist'
        ENV['TYPE'] = 'type'
        # VCR will fail if the env argument on create does not add up.
        ret = c.run(Cmd: ['bash', '-c', "echo #{@job_name}"])
        assert_equal(0, ret)
      end
    ensure
      ENV.delete('DIST')
      ENV.delete('TYPE')
    end

    def test_cleanup_on_new
      vcr_it(__method__) do
        # Implicity via ctor
        Docker::Container.create(Image: @image).tap { |c| c.rename(@job_name) }
        Containment.new(@job_name, image: @image, binds: [])
        assert_raise Docker::Error::NotFoundError do
          Docker::Container.get(@job_name)
        end
      end
    end

    def test_cleanup_on_contain
      vcr_it(__method__) do
        begin
          # Implicit via contain. First construct containment then contain. Should
          # clean up first resulting in a different hash.
          c = Containment.new(@job_name, image: @image, binds: [])
          c2 = Docker::Container.create(Image: @image).tap { |c| c.rename(@job_name) }
          c1 = c.contain({})
          assert_not_equal(c1.id, c2.id)
          assert_raise Docker::Error::NotFoundError do
            # C2 should be gone entirely now
            Docker::Container.get(c2.id)
          end
        ensure
          c.cleanup if c
        end
      end
    end

    def test_bad_version
      # For the purposes of this test the fixture needs to be manually edited
      # when re-created to make the version appear incompatible again.
      vcr_it(__method__) do
        assert_raise do
          Containment.new(@job_name, image: @image, binds: [])
        end
      end
    end

    def test_ulimit
      vcr_it(__method__) do
        c = Containment.new(@job_name, image: @image, binds: [])
        # 1025 should be false
        ret = c.run(Cmd: ['bash', '-c',
                          'if [ "$(ulimit -n)" != "1025" ]; then exit 1; fi'])
        assert_equal(1, ret, 'ulimit is 1025 but should not be')
        # 1024 should be true
        ret = c.run(Cmd: ['bash', '-c',
                          'if [ "$(ulimit -n)" != "1024" ]; then exit 1; else exit 0; fi'])
        assert_equal(0, ret, 'ulimit -n is not 1024 but should be')
      end
    end

    def test_image_is_pangeaimage
      # All of the tests assume that the image we use is a PangeaImage, this
      # implicitly tests that the default arguments inside Containment actually
      # properly convert from PangeaImage to a String
      vcr_it(__method__) do
        assert_equal(@image.class, PangeaImage)
        c = Containment.new(@job_name, image: @image, binds: [])
        assert_equal(c.default_create_options[:Image], 'pangea/ubuntu:vivid')
      end
    end

    def test_ZZZ_binds # Last test always! Changes VCR configuration.
      # Container binds were overwritten by Containment at some point, make
      # sure the binds we put in a re the binds that are passed to docker.
      vcr_it(__method__) do
        Dir.chdir(@tmpdir) do
          CI::EphemeralContainer.stubs(:create)
                                .with({ :binds => [@tmpdir], :Image => @image.to_s, :Privileged => false, :Cmd => ['bash', '-c', 'exit', '0'] })
                                .raises(CI::BindsPassed)
          c = Containment.new(@job_name, image: @image, binds: [Dir.pwd])
          assert_raise CI::BindsPassed do
            c.run(Cmd: %w(bash -c exit 0))
          end
        end
      end
    end

    def test_userns_docker
      # Trigger userns detection.
      Docker.stubs(:info).returns('DockerRootDir' => '/var/lib/docker/10.20')

      # We are mocking this manually. No VCR!
      Docker.stubs(:version).returns("Version"=>"1.11.1", "ApiVersion"=>"1.23", "GitCommit"=>"5604cbe", "GoVersion"=>"go1.5.4", "Os"=>"linux", "Arch"=>"amd64", "KernelVersion"=>"4.4.0-36-generic", "BuildTime"=>"2016-04-26T23:43:49.174056600+00:00")
      CI::Containment.any_instance.stubs(:cleanup).returns(true)

      Containment::TRAP_SIGNALS.each { |sig| assert_handler_not_set(sig) }
      CI::Containment.new('fooey', image: 'yolo')
      Containment::TRAP_SIGNALS.each { |sig| assert_handler_not_set(sig) }
    end
  end
end
