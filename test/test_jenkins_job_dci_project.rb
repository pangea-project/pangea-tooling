# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2021 Scarlett Moore <sgmoore@kde.org>
require_relative 'lib/testcase'
require_relative '../lib/ci/scm'
require_relative '../jenkins-jobs/dci/dci_project_multi_job'
require 'mocha/test_unit'

class JenkinsJobDCIProjectTest < TestCase
  def setup
    @flavor_dir = File.absolute_path("#{__dir__}/../jenkins-jobs/dci")
  end

  def test_nesting
    stub_request(:get, 'https://api.github.com/repos/netrunner-desktop')
      .with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' })
      .to_return(status: 200, body: '["netrunner-desktop","calamares-desktop","base-files"]', headers: { 'Content-Type' => 'text/json' })

    packaging_scm = CI::SCM.new('git', 'git://yolo.com/example', 'master')

    project = mock('project')
    project.stubs(:name).returns('foobar')
    project.stubs(:component).returns('barfoo')
    project.stubs(:dependees).returns([])
    project.stubs(:upstream_scm).returns(nil)
    project.stubs(:packaging_scm).returns(packaging_scm)
    project.stubs(:series).returns('2021')
    project.stubs(:debian?).returns(true)
    project.stubs(:release_type).returns('desktop')
    project.stubs(:architecture).returns('amd64')

    jobs = DCIProjectMultiJob.job(
      project,
      series: '2021',
      architecture: 'amd64',
      release_type: 'desktop',
      upload_map: nil)
    project_job = jobs.find { |x| x.is_a?(DCIProjectMultiJob) }
    assert_not_nil(project_job)
    jobs = project_job.instance_variable_get(:@nested_jobs)
    jobs.each do |job|
      next unless job.is_a?(Array)
    end
  end

  def teardown
    # This is a class variable rather than class-instance variable, so we need
    # to reset this lest other tests may want to fail.
    @flavor_dir = nil
  end
end
