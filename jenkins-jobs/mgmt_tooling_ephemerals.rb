# frozen_string_literal: true
require_relative 'job'

class MGMTToolingEphemerals < JenkinsJob

  def initialize
    super('mgmt_tooling_ephemerals', 'mgmt_tooling_ephemerals.xml.erb')
  end
end
