# frozen_string_literal: true
require_relative 'job'

class MGMTToolingUpdateSubmodules < JenkinsJob

  def initialize
    super('mgmt_tooling_update_submodules', 'mgmt_tooling_update_submodules.xml.erb')
  end
end
