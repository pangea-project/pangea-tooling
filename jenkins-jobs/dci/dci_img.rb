# frozen_string_literal: true
require_relative '../job'
require_relative '../../lib/dci'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :branch
  attr_reader :release_distribution
  attr_reader :release_type
  attr_reader :architecture
  attr_reader :series

  def initialize(series:, release_type:, release:, architecture:, repo:, branch:)
    @series = series
    @release_type = release_type
    @release = release
    @release_distribution = DCI.release_distribution(@release, @series)
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{@release_type}_#{@release_distribution}_#{@architecture}", 'dci_img.xml.erb')
  end
end
