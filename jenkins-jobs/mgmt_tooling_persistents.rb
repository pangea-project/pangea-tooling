# frozen_string_literal: true
require_relative 'job'

class MGMTToolingPersistents < JenkinsJob

  def initialize
    super('mgmt_tooling_persistents', 'mgmt_tooling_persistents.xml.erb')
  end
end
