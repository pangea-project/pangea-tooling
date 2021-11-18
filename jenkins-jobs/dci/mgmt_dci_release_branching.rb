# frozen_string_literal: true
require_relative '../job'

#Job to create dci repos
class MGMTDCIReleaseBranchingJob < JenkinsJob
  def initialize
    super('mgmt_dci_release_branching', 'mgmt_dci_release_branching.xml.erb')
  end
end