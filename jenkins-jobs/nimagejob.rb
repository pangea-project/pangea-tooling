require_relative 'job'

class NetrunnerImageJob < JenkinsJob
  attr_reader :repo
  attr_reader :distribution
  attr_reader :architecture

  def initialize(distribution:, architecture:, repo:, component:)
    super("img_#{component}_#{distribution}_#{architecture}", 'nimg.xml.erb')
    @distribution = distribution
    @architecture = architecture
    @repo = repo
  end
end
