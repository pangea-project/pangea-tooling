# frozen_string_literal: true
require_relative '../job'


EXCLUDE_UPSTREAM_SCM = %w[mintinstall rootactions-servicemenu
                          software-properties
                          ds9-common
                          ds9-artwork
                          ].freeze
# source builder
class DCISourcerJob < JenkinsJob
  attr_reader :name
  attr_reader :basename
  attr_reader :upstream_scm
  attr_reader :type
  attr_reader :distribution
  attr_reader :packaging_scm
  attr_reader :packaging_branch
  attr_reader :downstream_triggers
  attr_reader :component

  def initialize(basename, project:, type:, distribution:, architecture:)
    super("#{basename}_#{architecture}_src", 'dci_sourcer.xml.erb')
    @name = project.name
    @component = project.component
    @basename = basename
    @upstream_scm = project.upstream_scm
    @type = type
    @distribution = distribution
    @packaging_scm = project.packaging_scm.dup
    @packaging_scm.url.gsub!('git.debian.org:/git/',
                             'git://anonscm.debian.org/')

    @packaging_branch = @packaging_scm.branch

    @downstream_triggers = []
  end

  def trigger(job)
    @downstream_triggers << job.job_name
  end

  def render_upstream_scm
    if !EXCLUDE_UPSTREAM_SCM.include?(@name) || !EXCLUDE_UPSTREAM_SCM.include?(@component)
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
  end

  def fetch_tarball
    return '' unless @upstream_scm&.type == 'tarball'
    "if [ ! -d source ]; then
    mkdir source
    fi
    echo '#{@upstream_scm.url}' > source/url"
  end

end
