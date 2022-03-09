# frozen_string_literal: true
require_relative '../job'
require_relative '../../lib/dci'

# source builder
class DCISourcerJob < JenkinsJob
  attr_reader :name
  attr_reader :basename
  attr_reader :upstream_scm
  attr_reader :type
  attr_reader :release
  attr_reader :release_type
  attr_reader :distribution
  attr_reader :series
  attr_reader :packaging_scm
  attr_reader :packaging_branch
  attr_reader :component
  attr_reader :architecture

  def initialize(basename, project:, series:, type:, release_type:, release:, architecture:)
    super("#{basename}_src", 'dci_sourcer.xml.erb')
    @name = project.name
    @component = project.component
    @type = type
    @basename = basename
    @upstream_scm = project.upstream_scm
    @release_type = release_type
    @release = release
    @series = series
    @architecture = architecture
    @packaging_scm = project.packaging_scm.dup
    @distribution = DCI.release_distribution(@release, @series)
    @packaging_branch = @packaging_scm.branch
  end

  def render_packaging_scm
    PackagingSCMTemplate.new(scm: @project.packaging_scm).render_template
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
      fetch_tarball
    else
      raise "Unknown upstream_scm type encountered '#{@upstream_scm.type}'"
    end
  end

  def fetch_tarball
    return '' unless @upstream_scm.type == 'tarball'

    "if [ ! -d source ]; then
    mkdir source
    fi
    echo ''#{@upstream_scm.url}" > 'source/url'
  end
end
