require_relative 'job'

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
    @merge_branches = %w(kubuntu_stable
                         kubuntu_stable_utopic
                         kubuntu_unstable
                         kubuntu_unstable_utopic
                         master
                         kubuntu_vivid_archive
                         kubuntu_vivid_backports)
    @dependees = dependees
  end
end
