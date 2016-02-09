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

# frozen_string_literal: true

require 'deep_merge'
require 'yaml'

require_relative 'pattern'

module CI
  # General prupose overrides handling (mostly linked to Project overrides).
  class Overrides
    DEFAULT_FILES = [
      File.expand_path("#{__dir__}/../../data/overrides/base.yaml")
    ].freeze

    class << self
      def default_files
        @default_files ||= DEFAULT_FILES
      end

      attr_writer :default_files
    end

    def initialize(files = self.class.default_files)
      @default_paths = files
    end

    def rules_for_scm(scm)
      # FIXME: branches make no sense for lunchpad, need a flat structure there.
      repo_patterns = repo_patterns_for_scm(scm)

      branch_patterns = repo_patterns.collect do |_pattern, branches|
        next nil unless branches
        patterns = CI::FNMatchPattern.filter(scm.branch, branches)
        patterns = CI::FNMatchPattern.sort_hash(patterns)
        next patterns if patterns
        nil
      end.compact # compact nils away.

      override_patterns_to_rules(branch_patterns)
    end

    private

    def repo_patterns_for_scm(scm)
      @overrides ||= global_override_load
      repo_patterns = CI::FNMatchPattern.filter(scm.url, @overrides)
      repo_patterns = CI::FNMatchPattern.sort_hash(repo_patterns)
      return {} if repo_patterns.empty?
      repo_patterns
    end

    # Flattens a pattern hash array into a hash of override rules.
    # Namely the overrides will be deep merged in order to cascade all relevant
    # rules against the first one.
    # @param branch_patterns Array<<Hash[PatternBase => Hash]> a pattern to
    #  rule hash sorted by precedence (lower index = better)
    # @return Hash of overrides
    def override_patterns_to_rules(branch_patterns)
      rules = {}
      branch_patterns.each do |patterns|
        patterns.each do |_pattern, override|
          # deep_merge() and deep_merge!() are different!
          # deep_merge! will merge and overwrite any unmergeables in destination
          #   hash
          # deep_merge will merge and skip any unmergeables in destination hash
          # NOTE: it is not clear to me why, but apparently we have unmergables
          #   probably however strings are unmergable and as such would either
          #   be replaced or not (this is the most mind numbingly dumb behavior
          #   attached to foo! that I ever saw, in particular considering the
          #   STL uses ! to mean in-place. So deep_merge! is behaviorwise not
          #   equal to merge! but deeper...)
          rules = rules.deep_merge(override)
        end
      end
      rules
    end

    def overrides
      @overrides ||= global_override_load
    end

    def global_override_load
      hash = {}
      @default_paths.each do |path|
        hash.deep_merge!(YAML.load(File.read(path)))
      end
      hash = CI::FNMatchPattern.convert_hash(hash, recurse: false)
      hash.each do |k, v|
        hash[k] = CI::FNMatchPattern.convert_hash(v, recurse: false)
      end
      hash
    end
  end
end
