# frozen_string_literal: true
require_relative '../job'

#Job to create dci repos
class MGMTCreateReposJob < JenkinsJob
  def initialize()
    super('mgmt_create_repos', 'mgmt_dci_create_repo.xml.erb')
  end
end
