# frozen_string_literal: true

# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../../lib/nci'
require_relative '../sourcer'
require_relative 'binarier'
require_relative 'lintcmakejob'
require_relative 'lintqmljob'
require_relative 'publisher'
require_relative '../multijob_phase'

# Magic builder to create an array of build steps
class ProjectJob < JenkinsJob
  def self.job(project, distribution:, architectures:, type:)
    return [] unless project.debian?

    architectures = architectures.dup
    architectures << 'i386' if %w[chafa-jammy libjpeg-turbo-jammy harfbuzz util-linux wayland libdrm-jammy libdrm lcms2-jammy wayland-jammy].any? { |x| project.name == x }

    basename = basename(distribution, type, project.component, project.name)

    dependees = project.dependees.collect do |d|
      basename(distribution, type, d.component, d.name)
    end

    # experimental has its dependencies in unstable
    if type == 'unstable'
      dependees += project.dependees.collect do |d|
        basename(distribution, 'experimental', d.component, d.name)
      end
    end

    dependees = dependees.compact.uniq.sort

    publisher_dependees = project.dependees.collect do |d|
      "#{basename(distribution, type, d.component, d.name)}_src"
    end.compact
    sourcer = SourcerJob.new(basename,
                             type: type,
                             distribution: distribution,
                             project: project)
    publisher = NeonPublisherJob.new(basename,
                                     type: type,
                                     distribution: distribution,
                                     dependees: publisher_dependees,
                                     component: project.component,
                                     upload_map: nil,
                                     architectures: architectures,
                                     project: project)
    binariers = architectures.collect do |architecture|
      job = BinarierJob.new(basename, type: type, distribution: distribution,
                                      architecture: architecture)
      scm = project.upstream_scm
      job.qt_git_build = (scm&.url&.include?('/qt/') && scm&.branch&.include?('5.15'))
      job.qt6_build = (scm&.url&.include?('/qt-6/')
      job
    end
    jobs = [sourcer, binariers, publisher]
    basename1 = jobs[0].job_name.rpartition('_')[0]
    unless basename == basename1
      raise "unexpected basename diff #{basename} v #{basename1}"
    end

    unless NCI.experimental_skip_qa.any? { |x| jobs[0].job_name.include?(x) }
      # After _pub
      lintqml = LintQMLJob.new(basename, distribution: distribution, type: type)
      lintcmake = LintCMakeJob.new(basename, distribution: distribution,
                                             type: type)
      jobs << [lintqml, lintcmake]
    end

    jobs << new(basename, distribution: distribution, project: project,
                          jobs: jobs, type: type, dependees: dependees)
    # The actual jobs array cannot be nested, so flatten it out.
    jobs.flatten
  end

  # @! attribute [r] jobs
  #   @return [Array<String>] jobs invoked as part of the multi-phases
  attr_reader :jobs

  # @! attribute [r] dependees
  #   @return [Array<String>] name of jobs depending on this job
  attr_reader :dependees

  # @! attribute [r] project
  #   @return [Project] project instance of this job
  attr_reader :project

  # @! attribute [r] upstream_scm
  #   @return [CI::UpstreamSCM] upstream scm instance of this job_name
  # FIXME: this is a compat thingy for sourcer (see render method)
  attr_reader :upstream_scm

  # @! attribute [r] distribution
  #   @return [String] codename of distribution
  attr_reader :distribution

  # @! attribute [r] type
  #   @return [String] type name of the build (e.g. unstable or something)
  attr_reader :type

  def self.basename(dist, type, component, name)
    "#{dist}_#{type}_#{component}_#{name}"
  end

  private

  def initialize(basename, distribution:, project:, jobs:, type:, dependees: [])
    super(basename, 'project.xml.erb')

    # We use nested jobs for phases with multiple jobs, we need to aggregate
    # them appropriately.
    job_names = jobs.collect do |job|
      next job.collect(&:job_name) if job.is_a?(Array)

      job.job_name
    end

    @distribution = distribution.dup.freeze
    @nested_jobs = job_names.dup.freeze
    @jobs = job_names.flatten.freeze
    @dependees = dependees.dup.freeze
    @project = project.dup.freeze
    @type = type.dup.freeze
  end

  def render_phases
    ret = ''
    @nested_jobs.each_with_index do |job, i|
      ret += MultiJobPhase.new(phase_name: "Phase#{i}",
                               phased_jobs: [job].flatten).render_template
    end
    ret
  end

  def render_packaging_scm
    scm = @project.packaging_scm_for(series: @distribution)
    PackagingSCMTemplate.new(scm: scm).render_template
  end

  def render_commit_hook_disabled
    # disable triggers for legacy series during transition-period
    return 'true' if NCI.old_series == distribution

    'false'
  end

  def render_upstream_scm
    @upstream_scm = @project.upstream_scm # FIXME: compat assignment
    return '' unless @upstream_scm # native packages have no upstream_scm

    case @upstream_scm.type
    when 'git', 'svn'
      render("upstream-scms/#{@upstream_scm.type}.xml.erb")
    when 'tarball', 'bzr', 'uscan'
      ''
    else
      raise "Unknown upstream_scm type encountered '#{@upstream_scm.type}'"
    end
  end
end
