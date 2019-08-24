# frozen_string_literal: true
require_relative '../job'

class DCIImageJob < JenkinsJob
  attr_reader :type
  attr_reader :repo
  attr_reader :release
  attr_reader :architecture
  attr_reader :flavor

  def initialize(type:, flavor:, release:, architecture:, repo:, branch:)
    @type = type
    @flavor = flavor
    @release = release
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{type}_#{flavor}_#{release}_#{architecture}", 'dci_img.xml.erb')
  end
end
