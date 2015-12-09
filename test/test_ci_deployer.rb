require 'docker'
require 'fileutils'
require 'json'
require 'ostruct'
require 'ruby-progressbar'
require 'vcr'

require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/dci'
require_relative '../ci-tooling/lib/dpkg'
require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/ci/pangeaimage'
require_relative '../lib/mgmt/deployer'

class DeployTest < TestCase
  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body],
        tag: :erb_pwd
      }

      # The PWD is used as home and as such it appears in the interactions.
      # Filter it into a ERB expression we can play back.
      config.filter_sensitive_data('<%= Dir.pwd %>', :erb_pwd) { Dir.pwd }

      # VCR records the binary tar image over the socket, so instead of actually
      # writing out the binary tar, replace it with nil since on replay docker
      # actually always sends out a empty body
      config.before_record do |interaction|
        if interaction.request.uri.end_with?('export')
          interaction.response.body = nil
        end
      end
    end

    @oldnamespace = CI::PangeaImage.namespace
    @namespace = 'pangea-testing'
    CI::PangeaImage.namespace = @namespace
    @oldhome = ENV.fetch('HOME')

    # Hardcode ubuntu as the actual live values change and that would mean
    # a) regenerating the test data for no good reason
    # b) a new series might entail an upgrade which gets focused testing
    #    so having it appear in broad testing doesn't make much sense.
    # NB: order matters here, first is newest, last is oldest
    @ubuntu_series = %w(wily vivid)
    @debian_series = DCI.series.keys
  end

  def teardown
    VCR.configuration.default_cassette_options.delete(:tag)
    CI::PangeaImage.namespace = @oldnamespace
    ENV['HOME'] = @oldhome
  end

  def copy_data
    FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
  end

  def load_relative(path)
    load(File.join(__dir__, path.to_str))
  end

  # create base
  def create_base(flavor, tag)
    b = CI::PangeaImage.new(flavor, tag)
    return if Docker::Image.exist?(b.to_s)

    deployer = MGMT::Deployer.new(flavor, tag)
    deployer.create_base
  end

  def remove_base(flavor, tag)
    b = CI::PangeaImage.new(flavor, tag)
    return unless Docker::Image.exist?(b.to_s)

    image = Docker::Image.get(b.to_s)
    # Do not prune to keep the history. Otherwise we have to download the
    # entire image in the _new test.
    image.delete(force: true, noprune: true)
  end

  def deploy_all
    @ubuntu_series.each do |k|
      d = MGMT::Deployer.new('ubuntu', k)
      d.run!
    end

    @debian_series.each do |k|
      d = MGMT::Deployer.new('debian', k)
      d.run!
    end
  end

  def test_deploy_new
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      @ubuntu_series.each do |k|
        remove_base('ubuntu', k)
      end

      @debian_series.each do |k|
        remove_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, erb: true) do
      assert_nothing_raised do
        deploy_all
      end
    end
  end

  def test_deploy_exists
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      @ubuntu_series.each do |k|
        create_base('ubuntu', k)
      end

      @debian_series.each do |k|
        create_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, erb: true) do
      assert_nothing_raised do
        deploy_all
      end
    end
  end

  def test_upgrade
    # When trying to provision an image for an ubuntu series that doesn't exist
    # in dockerhub we can upgrade from an earlier series. To do this we'd pass
    # the version to upgrade from and then expect create_base to actually
    # indicate an upgrade.
    copy_data
    ENV['HOME'] = Dir.pwd
    VCR.turned_off do
      remove_base(:ubuntu, 'wily')
      remove_base(:ubuntu, __method__)
    end

    VCR.use_cassette(__method__, erb: true) do
      # Wily should exist so the fallback upgrade shouldn't be used.
      d = MGMT::Deployer.new(:ubuntu, 'wily', %w(vivid))
      upgrade = d.create_base
      assert_nil(upgrade)
      # Fake series name shouldn't exist and trigger an upgrade.
      d = MGMT::Deployer.new(:ubuntu, __method__.to_s, %w(wily))
      upgrade = d.create_base
      assert_not_nil(upgrade)
      assert_equal('wily', upgrade.from)
      assert_equal(__method__.to_s, upgrade.to)
    end
  ensure
    VCR.turned_off do
      remove_base(:ubuntu, __method__)
    end
  end
end
