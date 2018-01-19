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

require_relative '../ci-tooling/test/lib/testcase'
require_relative '../nci/jenkins_job_artifact_cleaner_all'

require 'mocha/test_unit'

module NCI
  class JenkinsJobArtifactCleanerTest < TestCase
    def setup
      @jenkins_home = ENV['JENKINS_HOME']
      ENV['JENKINS_HOME'] = Dir.pwd
      @jenkins_job_base = ENV['JOB_BASE_NAME']
      ENV['JOB_BASE_NAME'] = 'foobasename'
      @jenkins_build_number = ENV['BUILD_NUMBER']
      ENV['BUILD_NUMBER'] = '42'
    end

    def teardown
      # If the var is nil []= delets it from the env.
      ENV['JENKINS_HOME'] = @jenkins_home
      ENV['JOB_BASE_NAME'] = @jenkins_job_base
      ENV['BUILD_NUMBER'] = @jenkins_build_number
    end

    def test_clean
      # All deb files should get ripped out.

      # job foo

      ## 3 so we test if clamping to 1 at the smallest works.
      foo_archive3 = 'jobs/foo/builds/3/archive'
      FileUtils.mkpath(foo_archive3)
      FileUtils.touch("#{foo_archive3}/aa.deb")

      ## skip 2 to see if a missing build doesn't crash

      ## 1 also has some litter
      foo_archive1 = 'jobs/foo/builds/1/archive'
      FileUtils.mkpath(foo_archive1)
      FileUtils.touch("#{foo_archive1}/aa.deb")

      ## symlink lastBuild->3
      FileUtils.ln_s('3', 'jobs/foo/builds/lastBuild', verbose: true)

      # job bar

      ## 200 so we test if we don't iterate the entire build history
      bar_archive200 = 'jobs/bar/builds/200/archive'
      FileUtils.mkpath(bar_archive200)
      FileUtils.touch("#{bar_archive200}/aa.deb")

      ## 100 also has some litter
      bar_archive100 = 'jobs/bar/builds/100/archive'
      FileUtils.mkpath(bar_archive100)
      FileUtils.touch("#{bar_archive100}/aa.deb")

      ## 99 also has some litter but shouldn't get cleaned
      bar_archive99 = 'jobs/bar/builds/99/archive'
      FileUtils.mkpath(bar_archive99)
      FileUtils.touch("#{bar_archive99}/aa.deb")

      ## symlink lastBuild->200
      FileUtils.ln_s('200', 'jobs/bar/builds/lastBuild')

      JenkinsJobArtifactCleaner::AllJobs.run

      assert_path_not_exist("#{foo_archive3}/aa.deb")
      assert_path_not_exist("#{foo_archive1}/aa.deb")

      assert_path_not_exist("#{bar_archive200}/aa.deb")
      assert_path_not_exist("#{bar_archive100}/aa.deb")
      assert_path_exist("#{bar_archive99}/aa.deb")
    end
  end
end
