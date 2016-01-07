require_relative 'builder'
require_relative 'multijob_phase'

# Magic builder to create an array of build steps
class Builder2 < JenkinsJob
  def self.job(*args, **kwords)
    project = args[0]
    dependees = project.dependees.collect do |d|
      Builder.basename(kwords[:distribution], kwords[:type], project.component, d)
    end
    project.dependees.clear

    jobs = Builder.job(*args, kwords)
    jobs.each do |j|
      # Disable downstream triggers to prevent jobs linking to one another
      # outside the phases.
      j.send(:instance_variable_set, :@downstream_triggers, [])
    end
    basename = jobs[0].job_name.rpartition('_')[0]
    puts basename

    jobs << new(basename, jobs: jobs.collect(&:job_name), dependees: dependees)
    jobs
  end

  # @! attribute [r] dependees
  #   @return [Array<String>] name of jobs depending on this job
  attr_reader :dependees

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
