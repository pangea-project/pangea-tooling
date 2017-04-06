require_relative 'job'
require_relative '../ci-tooling/lib/kci'

# Mergers merge a set of branches
class MergeJob < JenkinsJob
  attr_reader :name
  attr_reader :component
  attr_reader :merge_branches
  attr_reader :dependees

  def initialize(project, dependees:)
    super("merger_#{project.name}", 'merger.xml.erb')
    @name = project.name
    @component = project.component
    @merge_branches = %w[master]
    KCI.series.each_key do |series|
      @merge_branches << "kubuntu_#{series}_archive"
      @merge_branches << "kubuntu_#{series}_backports"
      KCI.types.each do |type|
        @merge_branches << "kubuntu_#{type}_#{series}"
      end
    end
    KCI.types.each do |type|
      @merge_branches << "kubuntu_#{type}"
    end
    @dependees = dependees
  end
end
