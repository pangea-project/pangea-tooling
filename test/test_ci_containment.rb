require 'vcr'

require_relative '../lib/ci/containment.rb'
require_relative '../ci-tooling/test/lib/testcase'

module CI
  class ContainmentTest < TestCase
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

      @job_name = 'vivid_unstable_test'
      @image = 'jenkins/vivid_unstable'

      begin
        # Make sure the default container name isn't used, it can screw up
        # the vcr data.
        c = Docker::Container.get(@job_name)
        c.stop
        c.kill!
        c.remove
      rescue
        Docker::Error::NotFoundError
      end
    end

    def test_init
      binds = [Dir.pwd, 'a:a']
      priv = true
      VCR.use_cassette(__method__) do
        c = Containment.new(@job_name, image: @image, binds: binds,
                                       privileged: priv)
        assert_equal(@job_name, c.name)
        assert_equal(@image, c.image)
        assert_equal(binds, c.binds)
        assert_equal(priv, c.privileged)
      end
    end

    def test_run
      binds = []
      VCR.use_cassette(__method__,) do
        c = Containment.new(@job_name, image: @image, binds: binds)
        ret = c.run(Cmd: ['bash', '-c', "echo #{@job_name}"])
        assert_equal(0, ret)

        ret = c.run(Cmd: ['garbage_fail'])
        assert_not_equal(0, ret)
      end
    end

    def test_run_env
      binds = []
      VCR.use_cassette(__method__) do
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
      VCR.use_cassette(__method__) do
        # Implicity via ctor
        Docker::Container.create(Image: @image).tap { |c| c.rename(@job_name) }
        Containment.new(@job_name, image: @image, binds: [])
        assert_raise Docker::Error::NotFoundError do
          Docker::Container.get(@job_name)
        end
      end
    end

    def test_cleanup_on_contain
      VCR.use_cassette(__method__) do
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
      VCR.use_cassette(__method__) do
        assert_raise do
          Containment.new(@job_name, image: @image, binds: [])
        end
      end
    end

    def test_ulimit
      VCR.use_cassette(__method__) do
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
  end
end
