# frozen_string_literal: true
require_relative '../job'

#Job to create dci repos
class MGMTCreateDockerhubImagesJob < JenkinsJob
  def initialize
    super('mgmt_create_dockerhub_images', 'mgmt_dci_create_dockerhub_images.xml.erb')
  end
end
