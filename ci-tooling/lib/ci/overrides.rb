# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'deep_merge'
require 'yaml'

require_relative 'pattern'

module CI
  # General prupose overrides handling (mostly linked to Project overrides).
  class Overrides
    DEFAULT_FILES = [
      File.expand_path("#{__dir__}/../../data/projects/overrides/base.yaml")
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
      # For launchpad rules need to use '*' or '' for branch. This is to keep
      # the override format consistent and not having to write separate
      # branches for launchpad here.
      repo_patterns = repo_patterns_for_scm(scm)

      branch_patterns = repo_patterns.collect do |_pattern, branches|
        next nil unless branches
        # launchpad has no branches so pretend the branch is empty. launchpad
        # having no branch the only valid values in the overrides would be
        # '*' and '', both of which would match an empty string branch, so
        # for the purpose of filtering let's pretend branch is empty when
        # not set at all.
        patterns = CI::FNMatchPattern.filter(scm.branch || '', branches)
        patterns = CI::FNMatchPattern.sort_hash(patterns)
        next patterns if patterns
        nil
      end.compact # compact nils away.

      override_patterns_to_rules(branch_patterns)
    end

    private

    def repo_patterns_for_scm(scm)
      @overrides ||= global_override_load
      # TODO: maybe rethink the way matching works. Actively matching against
      # an actual url is entirely pointless, we just need something that is
      # easy to understand and easy to compute. That could just be a sanitized
      # host/path string as opposed to the actual url. This then also means
      # we can freely mutate urls between writable and readonly (e.g. with
      # gitlab and github either going through ssh or https)
      url = scm.url.gsub(/\.git$/, '') # sanitize to simplify matching
      repo_patterns = CI::FNMatchPattern.filter(url, @overrides)
      repo_patterns = CI::FNMatchPattern.sort_hash(repo_patterns)
      return {} if repo_patterns.empty?
      repo_patterns
    end

    def nil_fix(h)
      h.each_with_object({}) do |(k, v), enumerable|
        enumerable[k] = v
        enumerable[k] = nil_fix(v) if v.is_a?(Hash)
        enumerable[k] ||= 'NilClass'
      end
    end

    def nil_unfix(h)
      h.each_with_object({}) do |(k, v), enumerable|
        enumerable[k] = v
        enumerable[k] = nil if v == 'NilClass'
        enumerable[k] = nil_unfix(v) if v.is_a?(Hash)
        enumerable[k]
      end
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
        patterns.each_value do |override|
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
          # NOTE: even more crap: deep_merge considers nil to mean nothing, but
          #   for us nothing has meaning. Basically if a key is nil we don't want
          #   it replaced, because nil is not undefined!! We have project overrides
          #   that set upstream_scm to nil which is to say if it is nil already
          #   do not override. So to bypass deep merge's assumption here we fixate
          #   the nil value and then unfixate it again.
          rules = rules.deep_merge(nil_fix(override))
        end
      end
      nil_unfix(rules)
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
