# frozen_string_literal: true
require_relative 'job'

class MGMTToolingNode < JenkinsJob

  def initialize
    super('mgmt_tooling_nodes', 'mgmt_tooling_nodes.xml.erb')
  end
end
