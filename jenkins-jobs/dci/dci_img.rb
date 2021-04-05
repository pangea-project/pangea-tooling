# frozen_string_literal: true
require_relative '../job'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :release_type
  attr_reader :architecture
  attr_reader :series

  def initialize(series:, release_type:, architecture:, repo:, branch:)
    @series = series
    @release_type = release_type
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{series}_#{release_type}_#{architecture}", 'dci_img.xml.erb')
  end
end
