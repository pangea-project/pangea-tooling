# frozen_string_literal: true
require_relative 'job'

# Deploy job
class MGMTDockerJob < JenkinsJob
  attr_reader :dependees

  def initialize(dependees:)
    name = 'mgmt_docker'
    super(name, "#{name}.xml.erb")
    @dependees = dependees.collect(&:job_name)
  end
end
