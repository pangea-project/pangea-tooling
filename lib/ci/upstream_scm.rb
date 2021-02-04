# frozen_string_literal: true
#
# SPDX-FileCopyrightText: 2014-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'git_clone_url'
require 'open-uri'
require 'releaseme'

require_relative 'scm'
require_relative '../retry'

module CI
  # Construct an upstream scm instance and fold in overrides set via
  # meta/upstream_scm.json.
  class UpstreamSCM < SCM
    # Caches projects so we don't construct them multiple times.
    module ProjectCache
      class << self
        def fetch(repo_url)
          hash.fetch(repo_url, nil)
        end

        # @return project
        def cache(repo_url, project)
          hash[repo_url] = project
          project
        end

        def skip(repo_url)
          hash[repo_url] = :skip
        end

        def skip?(repo_url)
          data = hash[repo_url]
          data == :skip
        end

        def reset!
          @hash = {}
        end

        private

        def hash
          @hash ||= {}
        end
      end
    end

    module Origin
      UNSTABLE = :unstable
      STABLE = :stable # aka stable
    end

    ORIGIN_PERFERENCE = [Origin::UNSTABLE, Origin::STABLE].freeze
    DEFAULT_BRANCH = 'master'

    # Constructs an upstream SCM description from a packaging SCM description.
    #
    # Upstream SCM settings default to sane KDE settings and can be overridden
    # via data/overrides/*.yml. The override file supports pattern matching
    # according to File.fnmatch and ERB templating using a Project as binding
    # context.
    #
    # @param packaging_repo [String] git URL of the packaging repo
    # @param packaging_branch [String] branch of the packaging repo
    # @param working_directory [String] local directory path of directory
    #   containing debian/ (this is only used for repo-specific overrides)
    def initialize(packaging_repo, packaging_branch,
                   working_directory = Dir.pwd)
      @packaging_repo = packaging_repo
      @packaging_branch = packaging_branch
      @name = File.basename(packaging_repo)
      @directory = working_directory

      repo_url = "https://anongit.kde.org/#{@name.chomp('-qt4')}"
      branch = DEFAULT_BRANCH

      # Should move elsewhere, no clue where though.
      # We releaseme_adjust urls as well and need read-only variants.
      ENV['RELEASEME_READONLY'] = '1'

      @default_url = repo_url.clone.freeze
      super('git', repo_url, branch)
    end

    # a bit too long but fairly straight forward and also not very complex
    # rubocop:disable Metrics/MethodLength
    def releaseme_adjust!(origin)
      # rubocop:enable Metrics/MethodLength
      return nil unless adjust?

      if personal_repo?
        warn "#{url} is a user repo, we'll not adjust it using releaseme info"
        ProjectCache.skip(url)
        return nil
      end

      # Plasma may have its branch overridden because of peculiar nuances in
      # the timing between branching and actual update of the metadata.
      # These are not global adjust? considerations so we have two methods
      # that instead make opinionated choices about whether or not the branch
      # or the url **may** be changed.
      adjust_branch_to(project, origin)
      adjust_url_to(project)
      self
    ensure
      # Assert that we don't have an anongit URL. But only if there is no
      # other pending exception lest we hide the underlying problem.
      assert_url unless $!
    end

    private

    def personal_repo?
      # FIXME: we already got the project in the factory. we could pass it through
      return false unless url.include?('invent.kde.org')

      # https://docs.gitlab.com/ee/api/README.html#namespaced-path-encoding
      path = URI.parse(url).path.gsub(/.git$/, '')
      path = path.gsub(%r{^/+}, '').gsub('/', '%2F')
      api_url = "https://invent.kde.org/api/v4/projects/#{path}"
      data = JSON.parse(open(api_url).read)
      data.fetch('namespace').fetch('kind') == 'user'
    rescue OpenURI::HTTPError => e
      raise "HTTP Error on '#{api_url}': #{e.message}"
    end

    def assert_url
      return unless type == 'git' && url&.include?('anongit.kde.org')

      raise <<~ERROR
        Upstream SCM has invalid url #{url}! Anongit is no more. Either
        this repo should have mapped to a KDE repo (and failed), or it has an
        invalid override, or it needs to have a manual override so it knows
        where to find its source (not automatically possible for !KDE).
        If this is a KDE repo debug why it failed to map and fix it.
        DO NOT OVERRIDE URLS FOR LEGIT KDE PROJECTS!
      ERROR
    end

    def default_url?
      raise unless @default_url # make sure this doesn't just do a nil compare

      @default_url == @url
    end

    def adjust_branch_to(project, origin)
      if default_branch?
        @branch = branch_from_origin(project, origin.to_sym)
      else
        warn <<~WARNING
          #{url} is getting redirected to proper KDE url, but its branch was
          changed by an override to #{@branch} already. The actually detected
          KDE branch will not be applied!
        WARNING
      end
    end

    def adjust_url_to(project)
      if default_url?
        @url = SCM.cleanup_uri(project.vcs.repository)
      else
        warn <<~WARNING
          #{url} would be getting redirected to proper KDE url, but its url was
          changed by an override already. The actually detected KDE url will
          not be applied!
        WARNING
      end
    end

    def project
      url = self.url.gsub(/.git$/, '') # sanitize
      project = ProjectCache.fetch(url)
      return project if project

      projects = Retry.retry_it(times: 5) do
        guess_project(url)
      end
      if projects.size != 1
        raise "Could not resolve #{url} to KDE project for #{@packaging_repo} branch #{@packaging_branch}. OMG. #{projects}"
      end

      ProjectCache.cache(url, projects[0]) # Caches nil if applicable.
    end

    def guess_project(url)
      projects = ReleaseMe::Project.from_repo_url(url)
      return projects unless projects.empty?

      # The repo path didn't yield a direct query result. We can only surmize
      # that it isn't a valid invent repo path, as a fall back try to guess
      # the project by its basename as an id.
      # On invent project names aren't unique but in lieu of a valid repo url
      # this is the best we can do.
      warn "Trying to guess KDE project for #{url}. This is a hack!"
      ReleaseMe::Project.from_find(File.basename(url))
    end

    # This implements a preference fallback system.
    # We get a requested origin but in case this origin is not actually set
    # we fall back to a lower level origin. e.g. stable is requested but not
    # set, we'll fall back to trunk (i.e. ~master).
    # This is to prevent us from ending up with no branch and in case the
    # desired origin is not set, a lower preference fallback is more desirable
    # than our hardcoded master.
    def branch_from_origin(project, origin)
      origin_map = { Origin::UNSTABLE => project.i18n_trunk,
                     Origin::STABLE => project.i18n_stable }
      ORIGIN_PERFERENCE[0..ORIGIN_PERFERENCE.index(origin)].reverse_each do |o|
        branch = origin_map.fetch(o)
        return branch unless branch.to_s.empty?
      end
      DEFAULT_BRANCH # If all fails, default back to default.
    end

    def default_branch?
      branch == DEFAULT_BRANCH
    end

    def adjust?
      url.include?('.kde.org') && type == 'git' &&
        !url.include?('/scratch/') && !url.include?('/clones/') &&
        !ProjectCache.skip?(url)
    end
  end
end

require_relative '../deprecate'
# Deprecated. Don't use.
class UpstreamSCM < CI::UpstreamSCM
  extend Deprecate
  deprecate :initialize, CI::UpstreamSCM, 2015, 12
end
