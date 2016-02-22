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

require_relative 'base'

class ProjectsFactory
  # Debian specific project factory.
  class Debian < Base
    DEFAULT_URL_BASE = 'git://anonscm.debian.org'.freeze

    # FIXME: same as in neon
    # FIXME: needs a writer!
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      type == 'git.debian.org'
    end

    private

    # FIXME: not exactly the same as in Neon. prefix is only here. could be in
    #   neon too though
    def split_entry(entry)
      parts = entry.split('/')
      name = parts[-1]
      component = parts[-2] || 'debian'
      [name, component, parts[0..-3]]
    end

    def params(str)
      name, component, prefix = split_entry(str)
      default_params.merge(
        name: name,
        component: component,
        url_base: "#{self.class.url_base}/#{prefix.join('/')}"
      )
    end

    # FIXME: test needs to check that we get the correct url out
    # FIXME: same as in neon
    def from_string(str, params = {})
      kwords = params(str)
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

    # FIXME: same as in neon
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

    # FIXME: same as in neon
    def each_pattern_value(subset)
      subset.each do |sub|
        pattern = sub.keys[0]
        value = sub.values[0]
        yield pattern, value
      end
    end

    # FIXME: same as in neon
    def match_path_to_subsets(path, subset)
      matches = {}
      each_pattern_value(subset) do |pattern, value|
        next unless pattern.match?(path)
        match = [path, value] # This will be an argument list for from_string.
        matches[pattern] = match
      end
      matches
    end

    def from_hash(hash)
      base, subset = split_hash(hash)
      raise 'not array' unless subset.is_a?(Array)

      selection = self.class.ls(base).collect do |path|
        next nil unless path.start_with?(base) # speed-up, these can't match...
        matches = match_path_to_subsets(path, subset)
        # Get best matching pattern.
        CI::PatternBase.sort_hash(matches).values[0]
      end
      selection.compact.collect { |s| from_string(*s) }
    end

    class << self
      def ls(base)
        # NOTE: unlike neon we have a segmented cache here for each base.
        #   This is vastly more efficient than listing recursively as we do not
        #   really know the maximum useful depth so a boundless find would take
        #   years as it needs to traverse the entire file tree of /git (or a
        #   subset at least). Since this includes the actual repos, their .git
        #   etc. it is not viable.
        #   Performance testing suggests that each ssh access takes
        #   approximately 1 second, which is very acceptable.
        @list_cache ||= {}
        return @list_cache[base] if @list_cache.key?(base)
        output = `ssh git.debian.org find /git/#{base} -maxdepth 1 -type d`
        raise 'Failed to find repo list on host' unless $? == 0
        @list_cache[base] = cleanup_ls(output).freeze
      end

      private

      def cleanup_ls(data)
        data.chop.split(' ').collect do |line|
          line.gsub('/git/', '').gsub('.git', '')
        end
      end
    end
  end
end
