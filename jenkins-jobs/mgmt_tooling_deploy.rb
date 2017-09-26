# frozen_string_literal: true
require_relative 'job'

# Tooling management job.
class MGMTToolingProgenitorJob < JenkinsJob
  attr_reader :downstreams

  def initialize(downstreams:)
    name = 'mgmt_tooling_progenitor'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
  end
end
