require_relative 'job'

# Base class for all Jenkins job descriptions/templates.
class BuildJob < JenkinsJob
  attr_reader :name
  attr_reader :component
  attr_reader :upstream_scm
  attr_reader :type
  attr_reader :distribution
  attr_reader :dependees
  attr_reader :dependencies
  attr_reader :packaging_branch

  # FIXME: maybe I shoudl just make all but name/component/scm writable?
  attr_reader :disabled
  attr_reader :daily_trigger
  attr_reader :downstream_triggers

  def initialize(project,
                 type:,
                 distribution:)
    super(BuildJob.build_name(distribution, type, project.name),
          'build.xml.erb')
    @name = project.name
    @component = project.component
    @upstream_scm = project.upstream_scm
    @type = type
    @distribution = distribution
    @dependees = project.dependees.collect { |d| build_name(d) }.compact
    # FIXME: frameworks is special, very special ...
    if project.component == 'frameworks'
      puts '========================================='
      p @dependees
      @dependees += project.dependees.collect do |d|
        self.class.build_name(@distribution, 'stable', d)
      end
      p @dependees
    end
    @dependencies = project.dependencies.collect { |d| build_name(d) }.compact
    # FIXME: why ever does the job have to do that?
    # Try the distribution specific branch name first.
    @packaging_branch = "kubuntu_#{type}_#{distribution}"
    unless project.series_branches.include?(@packaging_branch)
      @packaging_branch = "kubuntu_#{type}"
    end

    # FIXME: not parameterized, also not used apparently
    @downstream_triggers = []
  end

  def build_name(name)
    BuildJob.build_name(@distribution, @type, name)
  end

  def self.build_name(dist, type, name)
    "#{dist}_#{type}_#{name}"
  end
end
