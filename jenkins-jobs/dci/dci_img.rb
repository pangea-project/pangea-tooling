# frozen_string_literal: true
require_relative '../job'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr-reader :branch
  attr_reader :release
  attr_reader :release_type
  attr_reader :architecture
  attr_reader :series

  def initialize(series:, release_type:, release:, architecture:, repo:, branch:)
    @series = series
    @release_type = release_type
    @release = release
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{series}_#{release_type}_#{release}_#{architecture}", 'dci_img.xml.erb')
  end
end
