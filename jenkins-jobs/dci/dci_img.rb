# frozen_string_literal: true
require_relative '../job'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :type
  attr_reader :architecture
  attr_reader :series

  def initialize(series:, type:, architecture:, repo:, branch:)
    @series = series
    @type = type
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{series}_#{type}_#{architecture}", 'dci_img.xml.erb')
  end
end
