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
require_relative '../nci/jenkins_job_artifact_cleaner'

require 'mocha/test_unit'

module NCI
  class JenkinsJobArtifactCleanerTest < TestCase
    def setup
      @jenkins_home = ENV['JENKINS_HOME']
      ENV['JENKINS_HOME'] = Dir.pwd
    end

    def teardown
      if @jenkins_home.nil?
        ENV.delete('JENKINS_HOME')
      else
        ENV['JENKINS_HOME'] = @jenkins_home
      end
    end

    def test_clean
      # All deb files should get ripped out.

      aa_archive = 'jobs/aa/builds/lastSuccessfulBuild/archive'
      FileUtils.mkpath(aa_archive)
      FileUtils.mkpath("#{aa_archive}/subdir1.deb/")
      FileUtils.mkpath("#{aa_archive}/subdir2/")
      FileUtils.touch("#{aa_archive}/subdir2/aa.deb")
      FileUtils.touch("#{aa_archive}/subdir2/aa.udeb")
      FileUtils.touch("#{aa_archive}/subdir2/aa.deb.info.txt")
      FileUtils.touch("#{aa_archive}/subdir2/aa.deb.json")

      JenkinsJobArtifactCleaner.run(%w[aa bb])

      assert_path_exist("#{aa_archive}/subdir1.deb/")
      assert_path_exist("#{aa_archive}/subdir2/aa.deb.info.txt")
      assert_path_exist("#{aa_archive}/subdir2/aa.deb.json")
    end
  end
end
