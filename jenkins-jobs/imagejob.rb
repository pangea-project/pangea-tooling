require_relative 'job'

class ImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :release
  attr_reader :architecture
  attr_reader :flavor

  def initialize(flavor:, release:, architecture:, repo:, branch:)
    @flavor = flavor
    @release = release
    @architecture = architecture
    @repo = repo
    @branch = branch
    super("img_#{flavor}_#{release}_#{architecture}", 'img.xml.erb')
  end
end
