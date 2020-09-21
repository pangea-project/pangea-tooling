# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'

require_relative 'base'

class ProjectsFactory
  # Neon specific project factory.
  class Neon < Base
    DEFAULT_URL_BASE = 'https://invent.kde.org/neon'
    NEON_GROUP = 'neon'
    GITLAB_API_ENDPOINT = 'https://invent.kde.org/api/v4'
    GITLAB_PRIVATE_TOKEN = ''

    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      %w[packaging.neon.kde.org.uk packaging.neon.kde.org
         git.neon.kde.org anongit.neon.kde.org
         invent.kde.org].include?(type)
    end

    private

    def split_entry(entry)
      parts = entry.split('/')
      # throw out neon master group.
      # our grouping system by component becomes increasingly painful for one
      # components mean very little but most importantly they are all below
      # a leading group on invent.kde.org which requires extra hacks :|
      parts.shift if parts[0] == NEON_GROUP
      name = parts[-1]
      component = parts[0..-2].join('_') || 'neon'
      [name, component]
    end

    def params(str)
      name, component = split_entry(str)
      default_params.merge(
        name: name,
        component: component,
        url_base: self.class.url_base
      )
    end

    def from_string(str, args = {}, ignore_missing_branches: false)
      kwords = params(str)
      kwords.merge!(symbolize(args))
      # puts "new_project(#{kwords})"
      new_project(**kwords).rescue do |e|
        begin
          raise e
        rescue Project::GitNoBranchError => e
          raise e unless ignore_missing_branches
        end
      end
    end

    def split_hash(hash)
      clean_hash(*hash.first)
    end

    def clean_hash(base, subset)
      subset.collect! do |sub|
        # Coerce flat strings into hash. This makes handling more consistent
        # further down the line. Flat strings simply have empty properties {}.
        sub = sub.is_a?(Hash) ? sub : { sub => {} }
        # Convert the subset into a pattern matching set by converting the
        # keys into suitable patterns.
        key = sub.keys[0]
        sub[CI::FNMatchPattern.new(join_path(base, key))] = sub.delete(key)
        sub
      end
      [base, subset]
    end

    def each_pattern_value(subset)
      subset.each do |sub|
        pattern = sub.keys[0]
        value = sub.values[0]
        yield pattern, value
      end
    end

    def match_path_to_subsets(path, subset)
      matches = {}
      each_pattern_value(subset) do |pattern, value|
        next unless pattern.match?(path)

        value[:ignore_missing_branches] = pattern.to_s.include?('*')
        match = [path, value] # This will be an argument list for from_string.
        matches[pattern] = match
      end
      matches
    end

    def from_hash(hash)
      base, subset = split_hash(hash)
      raise 'not array' unless subset.is_a?(Array)

      selection = self.class.ls.collect do |path|
        next nil unless path.start_with?(base) # speed-up, these can't match...

        matches = match_path_to_subsets(path, subset)
        # Get best matching pattern.
        CI::PatternBase.sort_hash(matches).values[0]
      end
      selection.compact.collect { |s| from_string(*s) }
    end

    class << self
      def ls
        # NB: when listing more than path_with_namespace you will need to
        #   change a whole bunch of stuff in test tooling.
        return @listing if defined?(@listing) # Cache in class scope.

        client = ::Gitlab.client(
          endpoint: GITLAB_API_ENDPOINT,
          private_token: GITLAB_PRIVATE_TOKEN
        )

        # Gitlab sends over paginated replies, make sure we iterate till
        # no more results are being returned.
        repos = client.group_projects(NEON_GROUP, include_subgroups: true)
                      .auto_paginate
                      .collect(&:path_with_namespace)
        @listing = repos.flatten
      end
    end
  end
end
