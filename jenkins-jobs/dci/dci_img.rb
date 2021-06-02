# frozen_string_literal: true
require_relative '../job'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :release
  attr_reader :architecture
  attr_reader :series

  def initialize(series:, release:, architecture:, repo:, branch:)
    @series = series
    @release = release
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{series}_#{release}_#{architecture}", 'dci_img.xml.erb')
  end
end
