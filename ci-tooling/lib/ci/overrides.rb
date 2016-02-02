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
      @overrides ||= global_override_load
      repo_patterns = CI::Pattern.filter(scm.url, @overrides)
      repo_patterns = CI::Pattern.sort_hash(repo_patterns)
      return {} if repo_patterns.empty?

      branches = @overrides[repo_patterns.flatten.first]
      branch_patterns = CI::Pattern.filter(scm.branch, branches)
      branch_patterns = CI::Pattern.sort_hash(branch_patterns)
      return {} if branch_patterns.empty?

      branches[branch_patterns.flatten.first]
    end

    private

    def global_override_load
      hash = {}
      @default_paths.each do |path|
        hash.deep_merge!(YAML.load(File.read(path)))
      end
      hash = CI::Pattern.convert_hash(hash, recurse: false)
      hash.each do |k, v|
        hash[k] = CI::Pattern.convert_hash(v, recurse: false)
      end
      hash
    end
  end
end
