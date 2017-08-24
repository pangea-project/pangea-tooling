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
require_relative '../ci-tooling/lib/ci/scm'
require_relative '../jenkins-jobs/nci/project'

require 'mocha/test_unit'

class JenkinsJobNCIProjectTest < TestCase
  def setup
    ProjectJob.flavor_dir = File.absolute_path("#{__dir__}/../jenkins-jobs/nci")
  end

  def teardown
    # This is a class variable rather than class-instance variable, so we need
    # to reset this lest other tests may want to fail.
    ProjectJob.flavor_dir = nil
  end

  def test_nesting
    packaging_scm = CI::SCM.new('git', 'git://yolo.com/example', 'master')

    project = mock('project')
    project.stubs(:name).returns('foobar')
    project.stubs(:component).returns('barfoo')
    project.stubs(:dependees).returns([])
    project.stubs(:upstream_scm).returns(nil)
    project.stubs(:packaging_scm).returns(packaging_scm)
    project.stubs(:series_branches).returns([])

    jobs = ProjectJob.job(project, distribution: 'distrooo',
                                   architectures: %w[i386 armel],
                                   type: 'unstable')
    project_job = jobs.find { |x| x.is_a?(ProjectJob) }
    assert_not_nil(project_job)
    jobs = project_job.instance_variable_get(:@nested_jobs)
    qml_and_cmake_found = false
    binaries_found = false
    jobs.each do |job|
      next unless job.is_a?(Array)
      ary = job
      if %w[bin_i386 bin_armel].all? { |a| ary.any? { |x| x.include?(a) } }
        binaries_found = true
        next
      end
      if %w[lintqml lintcmake].all? { |a| ary.any? { |x| x.include?(a) } }
        qml_and_cmake_found = true
        next
      end
    end
    assert(qml_and_cmake_found, <<-EOF)
Could not find a nested lintqml and lintcmake in the list of jobs.
    EOF
    assert(binaries_found, <<-EOF)
Could not find a nested i386 and armel binary jobs in the list of jobs.
    EOF
  end
end
