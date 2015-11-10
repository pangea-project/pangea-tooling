require 'yaml'

require_relative '../ci-tooling/lib/ci/pattern'
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
  attr_reader :packaging_scm
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
    @packaging_scm = project.packaging_scm_scm
    # FIXME: why ever does the job have to do that?
    # Try the distribution specific branch name first
    warn 'build.rb does not use the branch attr of SCM and has a problem there'
    @packaging_branch = "kubuntu_#{type}_#{distribution}"
    unless project.series_branches.include?(@packaging_branch)
      @packaging_branch = "kubuntu_#{type}"
    end

    # FIXME: not parameterized, also not used apparently
    @downstream_triggers = []
  end

  def render_upstream_scm
    return '' unless @upstream_scm
    case @upstream_scm.type
    when 'git'
      render('upstream-scms/git.xml.erb')
    when 'svn'
      render('upstream-scms/svn.xml.erb')
    else
      fail "Unknown upstream_scm type encountered '#{@upstream_scm.type}'"
    end
  end

  def build_name(name)
    BuildJob.build_name(@distribution, @type, name)
  end

  def self.build_name(dist, type, name)
    "#{dist}_#{type}_#{name}"
  end

  def update
    repos = CI::Pattern.filter(@packaging_scm.url, config)
    repos.sort_by(&:first).each do |_, job_patterns|
      CI::Pattern.filter(@job_name, job_patterns).each do |_, enabled|
        return unless enabled
      end
    end
    super
  end

  private

  def self.config(directory)
    return @config if defined?(@config)
    @config = YAML.load(File.read("#{directory}/build.yml"))
    @config = CI::Pattern.convert_hash(@config, recurse: true)
  end

  def config
    self.class.config(@config_directory).clone
  end
end
