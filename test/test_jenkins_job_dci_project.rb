# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2021 Scarlett Moore <sgmoore@kde.org>
require_relative 'lib/testcase'
require_relative '../lib/ci/scm'
require_relative '../jenkins-jobs/dci/dci_project_multi_job'
require 'mocha/test_unit'

class JenkinsJobDCIProjectMultiJobTest < TestCase
  def setup
    DCIProjectMultiJob.flavor_dir = File.absolute_path("#{__dir__}/../jenkins-jobs/dci")
  end
  
  def teardown
    DCIProjectMultiJob.flavor_dir = nil
  end

  def test_nesting
    stub_request(:get, 'https://api.github.com/repos/netrunner-desktop')
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '["netrunner-desktop","calamares-desktop","base-files"]', headers: { 'Content-Type' => 'text/json' })

    packaging_scm = CI::SCM.new('git', 'git://yolo.com/example', 'master')
    upstream_scm = CI::SCM.new('git', 'git://yolo.com/example', 'master')

    project = mock('project')
    project.stubs(:name).returns('foobar')
    project.stubs(:component).returns('barfoo')
    project.stubs(:dependees).returns([])
    project.stubs(:upstream_scm).returns(upstream_scm)
    project.stubs(:packaging_scm).returns(packaging_scm)
    project.stubs(:debian?).returns(true)

    jobs = DCIProjectMultiJob.job(
      project,
      series: '2021',
      release: 'netrunner-core-c1',
      upload_map: nil,
      architecture: 'armhf'
      )
    project_job = jobs.find { |x| x.is_a?(DCIProjectMultiJob) }
    assert_not_nil(project_job)
    jobs = project_job.instance_variable_get(:@nested_jobs)
    jobs.each do |job|
      next unless job.is_a?(Array)
    end
  end
end
