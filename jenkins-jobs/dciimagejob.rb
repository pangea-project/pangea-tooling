require_relative 'job'

class DCIImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :distribution
  attr_reader :architecture
  attr_reader :component

  def initialize(distribution:, architecture:, repo:, component:, branch:)
    super("img_#{component}_#{distribution}_#{architecture}", 'dciimg.xml.erb')
    @distribution = distribution
    @architecture = architecture
    @repo = repo
    @component = component
    @branch = branch
  end
end
