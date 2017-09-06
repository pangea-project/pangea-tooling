# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

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
    DEFAULT_BRANCH = 'master'.freeze

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

      super('git', repo_url, branch)
    end

    def releaseme_adjust!(origin)
      return nil unless adjust?
      if project
        @branch = branch_from_origin(project, origin.to_sym)
        return self
      end
      # No or multiple results
      nil
    end

    private

    def project
      url = self.url.gsub(/.git$/, '') # sanitize
      project = ProjectCache.fetch(url)
      return project if project
      projects =
        Retry.retry_it(times: 5) do
          ReleaseMe::Project.from_repo_url(url)
        end
      if projects.size != 1
        raise "Could not resolve #{url} to KDE project. OMG. #{projects}"
      end
      ProjectCache.cache(url, projects[0]) # Caches nil if applicable.
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
        return branch if branch && !branch.empty?
      end
      DEFAULT_BRANCH # If all fails, default back to default.
    end

    def default_branch?
      branch == DEFAULT_BRANCH
    end

    def adjust?
      default_branch? && url.include?('.kde.org') && type == 'git'
    end
  end
end

require_relative '../deprecate'
# Deprecated. Don't use.
class UpstreamSCM < CI::UpstreamSCM
  extend Deprecate
  deprecate :initialize, CI::UpstreamSCM, 2015, 12
end
