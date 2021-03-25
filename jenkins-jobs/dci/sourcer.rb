# frozen_string_literal: true
require_relative '../job'


# source builder
class DCISourcerJob < JenkinsJob
  attr_reader :name
  attr_reader :basename
  attr_reader :upstream_scm
  attr_reader :type
  attr_reader :series
  attr_reader :packaging_scm
  attr_reader :packaging_branch
  attr_reader :downstream_triggers
  attr_reader :component
  attr_reader :architecture

  def initialize(basename, project:, type:, series:)
    super("#{basename}_src", 'dci_sourcer.xml.erb')
    @name = project.name
    @component = project.component
    @basename = basename
    @upstream_scm = project.upstream_scm
    @type = type
    @series = series
    @packaging_scm = project.packaging_scm.dup
    @packaging_scm.url.gsub!('salsa.debian.org',
                             'git://salsa.debian.org/')

    @packaging_branch = @packaging_scm.branch

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
      when 'uscan'
        ''
      when 'tarball'
        ''
      else
        raise "Unknown upstream_scm type encountered '#{@upstream_scm.type}'"
      end
  end

  def fetch_tarball
    return '' unless @upstream_scm.type == 'tarball'

    "if [ ! -d source ]; then
    mkdir source
    fi
    echo '#{@upstream_scm.url}' > source/url"
  end

end
