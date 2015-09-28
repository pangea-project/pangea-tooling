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
require_relative '../lib/ci/baseimage'

class DeployTest < TestCase
  def setup
    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :excon
      config.default_cassette_options = {
        match_requests_on:  [:method, :uri, :body]
      }

      # VCR records the binary tar image over the socket, so instead of actually
      # writing out the binary tar, replace it with nil since on replay docker
      # actually always sends out a empty body
      config.before_record do |interaction|
        if interaction.request.uri.end_with?('export')
          interaction.response.body = nil
        end
      end
    end

    # Make sure we inject the TESTING env var so that docker.rb does not enable
    # event logging
    ENV['TESTING'] = 'true'

    @oldhome = ENV.fetch('HOME')
  end

  def copy_data
    FileUtils.cp_r(Dir.glob("#{data}/*"), Dir.pwd)
  end

  def create_base(flavor, version)
    b = CI::BaseImage.new(flavor, version)
    # create base
    # FIXME: code duplication from docker
    unless Docker::Image.exist?(b.to_s)
      docker_image = "#{flavor}:#{version}"
      docker_image = "armbuild/#{flavor}:#{version}" if DPKG::HOST_ARCH == 'armhf'
      progressbar = nil
      image = Docker::Image.create(fromImage: docker_image) do |data|
        update = JSON.parse(data, object_class: OpenStruct)
        if progressbar.nil? && update.progressDetail && update.progress
          detail = update.progressDetail
          progressbar = ProgressBar.create(title: update.stats,
                                           total: detail.total)
        end
        if update.progressDetail && update.progress
          detail = update.progressDetail
          progressbar.total = detail.total
          progressbar.progress = detail.current
          progressbar = nil if progressbar.total == progressbar.progress
          next
        end
        puts update.status
      end
      image.tag(repo: b.repo, tag: b.tag)
    end
  end

  def remove_base(flavor, version)
    b = CI::BaseImage.new(flavor, version)
    # create base
    if Docker::Image.exist?(b.to_s)
      image = Docker::Image.get(b.to_s)
      image.delete(force: true)
    end
  end

  def test_deploy_exists
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      KCI.series.keys.each do |k|
        create_base('ubuntu', k)
      end

      DCI.series.keys.each do |k|
        create_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, erb: true) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def test_deploy_new
    copy_data

    ENV['HOME'] = Dir.pwd

    VCR.turned_off do
      KCI.series.keys.each do |k|
        remove_base('ubuntu', k)
      end

      DCI.series.keys.each do |k|
        remove_base('debian', k)
      end
    end

    VCR.use_cassette(__method__, erb: true) do
      assert_nothing_raised do
        require_relative '../mgmt/docker'
      end
    end
  end

  def teardown
    ENV['HOME'] = @oldhome
    ENV.delete('TESTING')
  end
end
