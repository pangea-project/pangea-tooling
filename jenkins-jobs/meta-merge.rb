# frozen_string_literal: true
require_relative 'job'

# Meta merger depending on all merges and is able to trigger them.
class MetaMergeJob < JenkinsJob
  attr_reader :downstream_triggers

  def initialize(downstream_jobs:)
    super('mgmt_merger', 'meta-merger.xml.erb')
    @downstream_triggers = downstream_jobs.collect(&:job_name)
  end
end
