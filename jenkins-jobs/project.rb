# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'builder'
require_relative 'multijob_phase'

# Magic builder to create an array of build steps
class ProjectJob < JenkinsJob
  def self.job(*args, **kwords)
    project = args[0]
    dependees = project.dependees.collect do |d|
      Builder.basename(kwords[:distribution], kwords[:type], project.component, d)
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

    jobs << new(basename, jobs: jobs.collect(&:job_name), dependees: dependees)
    jobs
  end

  # @! attribute [r] dependees
  #   @return [Array<String>] name of jobs depending on this job
  attr_reader :dependees

  private

  def initialize(basename, jobs:, dependees: [])
    super(basename, 'builder2.xml.erb')
    @jobs = jobs
    @dependees = dependees
  end

  def render_phases
    ret = ''
    @jobs.each_with_index do |job, i|
      ret += MultiJobPhase.new(phase_name: "Phase#{i}",
                               phased_jobs: [job]).render_template
    end
    ret
  end
end
