# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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

require_relative '../builder'
require_relative 'multijob_phase'

# Magic builder to create an array of build steps
class ProjectJob < JenkinsJob
  def self.job(*args, **kwords)
    project = args[0]
    dependees = project.dependees.collect do |d|
      Builder.basename(kwords[:distribution],
                       kwords[:type],
                       d.component,
                       d.name)
    end
    # FIXME: frameworks is special, very special ...
    # Base builds have no stable thingy but their unstable version is equal
    # to their not unstable version.
    if %w(forks frameworks qt).include?(project.component)
      dependees += project.dependees.collect do |d|
        Builder.basename(kwords[:distribution],
                         'stable',
                         d.component,
                         d.name)
      end
    end
    dependees.compact!
    dependees.uniq!
    dependees.sort!
    project.dependees.clear

    jobs = Builder.job(*args, kwords)
    jobs.each do |j|
      # Disable downstream triggers to prevent jobs linking to one another
      # outside the phases.
      j.send(:instance_variable_set, :@downstream_triggers, [])
    end
    basename = jobs[0].job_name.rpartition('_')[0]

    jobs << new(basename,
                project: project,
                jobs: jobs.collect(&:job_name),
                dependees: dependees)
    jobs
  end

  # @! attribute [r] jobs
  #   @return [Array<String>] jobs invoked as part of the multi-phases
  attr_reader :jobs

  # @! attribute [r] dependees
  #   @return [Array<String>] name of jobs depending on this job
  attr_reader :dependees

  # @! attribute [r] project
  #   @return [Project] project instance of this job
  attr_reader :project

  # @! attribute [r] upstream_scm
  #   @return [CI::UpstreamSCM] upstream scm instance of this job_name
  # FIXME: this is a compat thingy for sourcer (see render method)
  attr_reader :upstream_scm

  private

  def initialize(basename, project:, jobs:, dependees: [])
    super(basename, 'builder2.xml.erb')
    @jobs = jobs.freeze
    @dependees = dependees.freeze
    @project = project.freeze
  end

  def render_phases
    ret = ''
    @jobs.each_with_index do |job, i|
      ret += MultiJobPhase.new(phase_name: "Phase#{i}",
                               phased_jobs: [job]).render_template
    end
    ret
  end

  def render_upstream_scm
    @upstream_scm = @project.upstream_scm # FIXME: compat assignment
    return '' unless @upstream_scm
    case @upstream_scm.type
    when 'git'
      render('upstream-scms/git.xml.erb')
    when 'svn'
      render('upstream-scms/svn.xml.erb')
    when 'tarball'
      ''
    when 'bzr'
      ''
    else
      raise "Unknown upstream_scm type encountered '#{@upstream_scm.type}'"
    end
  end
end
