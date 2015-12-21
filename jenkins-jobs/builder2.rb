require_relative 'builder'
require_relative 'multijob_phase'

# Magic builder to create an array of build steps
class Builder2 < JenkinsJob
  def self.job(*args)
    jobs = Builder.job(*args)
    basename = jobs[0].job_name.rpartition('_')[0]
    puts basename

    require 'ap'
    ap jobs
    jobs << new(basename, jobs: jobs.collect(&:job_name))
    ap jobs
    jobs
  end

  def initialize(basename, jobs:)
    super(basename, 'builder2.xml.erb')
    @jobs = jobs
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
