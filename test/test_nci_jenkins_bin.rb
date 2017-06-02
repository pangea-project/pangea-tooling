# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../ci-tooling/nci/lib/settings' # so we have the bloody module
require_relative '../ci-tooling/test/lib/testcase'
require_relative '../nci/jenkins_bin'

require 'mocha/test_unit'

module NCI::JenkinsBin
  class JenkinsBinTest < TestCase
    { Cores::CORES[0] => Cores::CORES[0], 4 => 2, 8 => 4 }.each do |input, output|
      define_method("test_cores_downgrade_#{input}") do
        assert_equal(output, Cores.downgrade(input))
      end
    end

    { 2 => 4, 4 => 8, Cores::CORES[-1] => Cores::CORES[-1] }.each do |input, output|
      define_method("test_cores_upgrade_#{input}") do
        assert_equal(output, Cores.upgrade(input))
      end
    end

    def test_slave
      assert_equal(8, Slave.cores('jenkins-do-8core.build.neon-0f321b00-a90f-4a3d-8d40-542681753686'))
      assert_equal(2, Slave.cores('jenkins-do-2core.build.neon-841d6c13-c583-4b13-b094-68576ef46062'))
      assert_equal(2, Slave.cores('do-builder-006'))
      assert_raises { Slave.cores('meowmoewkittenmoew') } # unknown name
    end
  end

  class BuildSelectorTest < TestCase
    attr_accessor :log_out
    attr_accessor :logger
    attr_accessor :jenkins_job
    attr_accessor :job

    def setup
      @log_out = StringIO.new
      @logger = Logger.new(@log_out)

      @jenkins_job = mock('job')
      @jenkins_job.stubs(:name).returns('kitteh')

      @job = mock('job')
      @job.responds_like_instance_of(Job)
      @job.stubs(:log).returns(@logger)
      @job.stubs(:last_build_number).returns(7)
      @job.stubs(:job).returns(@jenkins_job)
    end

    def teardown
      return if passed?
      @log_out.rewind
      warn @log_out.read
    end

    def test_build_selector
      8.times do |i|
        jenkins_job.stubs(:build_details).with(i).returns(
          'result' => 'SUCCESS',
          'builtOn' => 'jenkins-do-8core.build.neon-123123'
        )
      end

      selector = BuildSelector.new(job)
      builds = selector.select
      assert(builds)
      refute(builds.empty?)
    end

    def test_build_selector_bad_slave_chain
      jenkins_job.stubs(:build_details).with(7).returns(
        'result' => 'SUCCESS',
        'builtOn' => 'jenkins-do-8core.build.neon-123123'
      )
      7.times do |i|
        jenkins_job.stubs(:build_details).with(i).returns(
          'result' => 'SUCCESS',
          'builtOn' => 'jenkins-do-4core.build.neon-123123'
        )
      end

      selector = BuildSelector.new(job)
      builds = selector.select
      refute(builds)
    end

    def test_build_selector_404
      8.times do |i|
        jenkins_job.stubs(:build_details).with(i).raises(JenkinsApi::Exceptions::NotFound.allocate)
      end

      selector = BuildSelector.new(job)
      assert_raises { selector.select }
    end
  end

  class JobTest < TestCase
    def test_keep_cores
      current = 4
      expected = current

      selector = mock('selector')
      selector.stubs(:select).returns([{ 'duration' => 4 * 60 * 1000 }])
      selector.stubs(:detected_cores).returns(current)
      BuildSelector.expects(:new).returns(selector)

      assert_equal(expected, Job.new('kitteh').cores)
    end

    def test_up_cores
      current = 4
      expected = 8

      selector = mock('selector')
      selector.stubs(:select).returns([{ 'duration' => 45 * 60 * 1000 }])
      selector.stubs(:detected_cores).returns(current)
      BuildSelector.expects(:new).returns(selector)

      assert_equal(expected, Job.new('kitteh').cores)
    end

    def test_down_cores
      current = 4
      expected = 2

      selector = mock('selector')
      selector.stubs(:select).returns([{ 'duration' => 1 * 60 * 1000 }])
      selector.stubs(:detected_cores).returns(current)
      BuildSelector.expects(:new).returns(selector)

      assert_equal(expected, Job.new('kitteh').cores)
    end
  end

  class JobScorerTest < TestCase
    def test_run
      config_file = "#{Dir.pwd}/conf.json"
      File.write(config_file, '{"kitteh_bin_amd64":2,"meow_bin_amd64":2}')

      JenkinsApi::Client::Job.any_instance.stubs(:list_all).returns(
        %w[kitteh_bin_amd64]
      )

      job = mock('job')
      job.stubs(:cores).returns(2)
      Job.expects(:new).with('kitteh_bin_amd64').returns(job)

      @scorer = JobScorer.new(config_file: config_file)
      @scorer.run!

      assert_path_exist(config_file)
      assert_equal({ 'kitteh_bin_amd64' => 2 }, JSON.parse(File.read(config_file)))
    end
  end
end
