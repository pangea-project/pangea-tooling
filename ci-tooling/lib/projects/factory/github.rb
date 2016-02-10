# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'octokit'

require_relative 'base'

class ProjectsFactory
  # Debian specific project factory.
  class GitHub < Base
    DEFAULT_URL_BASE = 'https://github.com'.freeze

    # FIXME: same as in neon
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'github.com'
    end

    private

    # FIXME: same as in Neon except component is merged
    def split_entry(entry)
      parts = entry.split('/')
      name = parts[-1]
      component = parts[0..-2].join('_') || 'github'
      [name, component]
    end

    def default_params(str)
      name, component = split_entry(str)
      {
        name: name,
        component: component,
        url_base: "#{self.class.url_base}/",
        branch: 'kubuntu_unstable'
      }
    end

    # FIXME: test needs to check that we get the correct url out
    # FIXME: same as in neon
    def from_string(str, params = {})
      kwords = default_params(str)
      kwords.merge!(symbolize(params))
      new_project(**kwords)
    rescue Project::GitTransactionError, RuntimeError => e
      p e
      nil
    end

    # FIXME: same as in neon
    def split_hash(hash)
      clean_hash(*hash.first)
    end

    # FIXME: NOT same as in neon, pattern is different!
    def clean_hash(base, subset)
      subset.collect! do |sub|
        # Coerce flat strings into hash. This makes handling more consistent
        # further down the line. Flat strings simply have empty properties {}.
        sub = sub.is_a?(Hash) ? sub : { sub => {} }
        # Convert the subset into a pattern matching set by converting the
        # keys into suitable patterns.
        key = sub.keys[0]
        sub[CI::FNMatchPattern.new(key.to_s)] = sub.delete(key)
        sub
      end
      [base, subset]
    end

    # FIXME: same as in neon
    def each_pattern_value(subset)
      subset.each do |sub|
        pattern = sub.keys[0]
        value = sub.values[0]
        yield pattern, value
      end
    end

    # FIXME: NOT same as in neon path is not final path but just the name
    def match_path_to_subsets(base, name, subset)
      matches = {}
      each_pattern_value(subset) do |pattern, value|
        next unless pattern.match?(name)
        match = ["#{base}/#{name}", value]
        matches[pattern] = match
      end
      matches
    end

    def from_hash(hash)
      base, subset = split_hash(hash)
      fail 'not array' unless subset.is_a?(Array)

      selection = self.class.ls(base).collect do |name|
        matches = match_path_to_subsets(base, name, subset)
        # Get best matching pattern.
        CI::PatternBase.sort_hash(matches).values[0]
      end
      selection.compact.collect { |s| from_string(*s) }
    end

    class << self
      def ls(base)
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)
        repos = Octokit.organization_repositories(base)
        @list_cache[base] = repos.collect(&:name).freeze
      end
    end
  end
end
