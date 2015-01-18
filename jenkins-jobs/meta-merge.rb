require_relative 'job'

class MetaMergeJob < JenkinsJob
  attr_reader :downstream_triggers

  def initialize(downstream_jobs:)
    super('mgmt_merger', 'meta-merger.xml.erb')
    @downstream_triggers = downstream_jobs.collect(&:job_name)
  end
end
