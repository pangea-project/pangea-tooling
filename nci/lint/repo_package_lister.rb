# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../../lib/aptly-ext/filter'
require_relative '../../lib/dpkg'
require_relative '../../lib/retry'
require_relative '../../lib/nci'
require_relative '../../lib/aptly-ext/remote'

module NCI
  # Lists all architecture relevant packages from an aptly repo.
  class RepoPackageLister
    def self.default_repo
      "#{ENV.fetch('TYPE')}_#{ENV.fetch('DIST')}"
    end

    def self.current_repo
      "#{ENV.fetch('TYPE')}_#{NCI.current_series}"
    end

    def self.old_repo
      if NCI.future_series
        "#{ENV.fetch('TYPE')}_#{NCI.current_series}" # "old" is the current one
      elsif NCI.old_series
        "#{ENV.fetch('TYPE')}_#{NCI.old_series}"
      else
        raise "Don't know what old or future is, maybe this job isn't" \
              ' necessary and should be deleted?'
      end
    end

    def initialize(repo = Aptly::Repository.get(self.class.default_repo),
                   filter_select: nil)
      @repo = repo
      @filter_select = filter_select
    end

    def packages
      @packages ||= begin
        packages = Retry.retry_it(times: 4, sleep: 4) do
          @repo.packages(q: '!$Architecture (source)')
        end
        packages = Aptly::Ext::LatestVersionFilter.filter(packages)
        arch_filter = [DPKG::HOST_ARCH, 'all']
        packages = packages.select { |x| arch_filter.include?(x.architecture) }
        return packages unless @filter_select

        packages.select { |x| @filter_select.include?(x.name) }
      end
    end
  end
end
