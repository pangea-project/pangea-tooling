# frozen_string_literal: true
require_relative 'job'

# Tooling management job.
class MGMTToolingProgenitorJob < JenkinsJob
  attr_reader :downstreams
  attr_reader :also_trigger

  def initialize(downstreams:, also_trigger: [])
    name = 'mgmt_tooling_progenitor'
    super(name, "#{name}.xml.erb")
    @downstreams = downstreams
    @also_trigger = also_trigger
  end
end
