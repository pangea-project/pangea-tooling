require 'test/unit'
require 'vcr'

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../lib/jenkins/daily_run'

class JenkinsDailyRunTest < TestCase
  self.test_order = :defined

  def setup
    @job_url = 'http://kci.pangea.pub/job/mgmt_daily_promotion_utopic_stable'

    VCR.configure do |config|
      config.cassette_library_dir = @datadir
      config.hook_into :webmock
    end
    WebMock.disable_net_connect!
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
