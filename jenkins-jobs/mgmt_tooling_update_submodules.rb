# frozen_string_literal: true
require_relative 'job'

class MgmtToolingUpdateSubmodules < JenkinsJob
  attr_reader :downstreams

  def initialize(downstream_jobs:)
    super('mgmt_tooling_update_submodules', 'mgmt_tooling_update_submodules.xml.erb')
    @downstream_triggers = downstream_jobs.collect(&:job_name)
  end
end
