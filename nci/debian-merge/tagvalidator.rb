# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'yaml'

require_relative '../../ci-tooling/lib/ci/pattern'

module NCI
  module DebianMerge
    # Helper to validate tag expectations and possibly override.
    class TagValidator
      DEFAULT_PATH = "#{__dir__}/data/tag-overrides.yaml".freeze

      class << self
        def default_path
          @default_path ||= DEFAULT_PATH
        end
        attr_writer :default_path

        def reset!
          @default_path = nil
        end
      end

      def initialize(path = self.class.default_path)
        @default_path = path
      end

      def valid?(repo_url, expected_tag_base, latest_tag)
        puts "#{repo_url}, #{expected_tag_base}, #{latest_tag}"
        return true if latest_tag.start_with?(expected_tag_base)
        warn 'Tag expectations not matching, checking overrides.'
        patterns = CI::FNMatchPattern.filter(repo_url, overrides)
        CI::FNMatchPattern.sort_hash(patterns).any? do |_pattern, rules|
          rules.any? do |base, whitelist|
            p base, whitelist
            next false unless base == expected_tag_base
            whitelist.any? { |x| latest_tag.start_with?(x) }
          end
        end
      end

      private

      def overrides
        @overrides ||= begin
          hash = YAML.load(File.read(@default_path))
          CI::FNMatchPattern.convert_hash(hash, recurse: false)
        end
      end
    end
  end
end
