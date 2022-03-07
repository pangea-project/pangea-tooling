# frozen_string_literal: true
require_relative '../job'
require_relative '../../lib/dci'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :branch
  attr_reader :distribution
  attr_reader :release_type
  attr_reader :release
  attr_reader :series
  attr_reader :architecture

  def initialize(series:, release_type:, release:, architecture:, repo:, branch:)
    super("img_#{release_type}_#{release}-#{series}_#{architecture}", 'dci_img.xml.erb')
    @release_type = release_type
    @release = release
    @series = series
    @distribution = DCI.release_distribution(@release, series)
    @architecture = architecture
    @repo = repo
    @branch = branch
  end
end
