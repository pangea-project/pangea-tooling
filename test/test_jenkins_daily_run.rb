require 'test/unit'
require 'vcr'

require_relative '../lib/jenkins/daily_run'

VCR.configure do |config|
  config.cassette_library_dir = "data/#{File.basename(__FILE__, '.rb')}"
  config.hook_into :webmock
end

class JenkinsDailyRunTest < Test::Unit::TestCase
  self.test_order = :defined

  def setup
    @tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(@tmpdir)
    @job_url = 'http://kci.pangea.pub/job/mgmt_daily_promotion_utopic_stable'
  end

  def teardown
    Dir.chdir('/')
    FileUtils.rm_rf(@tmpdir)
  end

  def test_manually_triggered
    VCR.use_cassette(__method__) do
      job = Jenkins::DailyRun.new(job_url: @job_url, build_number: 179)
      assert(job.manually_triggered?)
    end
  end

  def test_not_manually_triggered
    VCR.use_cassette(__method__) do
      job = Jenkins::DailyRun.new(job_url: @job_url, build_number: 256)
      assert(!job.manually_triggered?)
    end
  end

  def test_not_run
    VCR.use_cassette(__method__) do
      job = Jenkins::DailyRun.new(job_url: @job_url, build_number: 256)
      assert(!job.ran_today?)
    end
  end

  def test_run
    VCR.use_cassette(__method__) do
      job = Jenkins::DailyRun.new(job_url: @job_url, build_number: 257)
      assert(job.ran_today?)
    end
  end
end
