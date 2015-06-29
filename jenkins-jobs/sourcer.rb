require_relative 'job'

# source builder
class SourcerJob < JenkinsJob
  attr_reader :name
  attr_reader :upstream_scm
  attr_reader :type
  attr_reader :distribution
  attr_reader :packaging_scm
  attr_reader :packaging_branch
  attr_reader :downstream_triggers

  def initialize(basename, project:, type:, distribution:)
    super("#{basename}_src", 'sourcer.xml.erb')
    @name = project.name
    @upstream_scm = project.upstream_scm
    @type = type
    @distribution = distribution
    @packaging_scm = project.packaging_scm.gsub('git.debian.org:/git/', 'git://anonscm.debian.org/')
    # FIXME: why ever does the job have to do that?
    # Try the distribution specific branch name first.
    @packaging_branch = "kubuntu_#{type}_#{distribution}"
    unless project.series_branches.include?(@packaging_branch)
      @packaging_branch = "kubuntu_#{type}"
    end

    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
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
end
