# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require 'tty/command'

require_relative 'base'

class ProjectsFactory
  # Neon specific project factory.
  class Neon < Base
    DEFAULT_URL_BASE = 'https://anongit.neon.kde.org'

    # FIXME: needs a writer!
    def self.url_base
      @url_base ||= DEFAULT_URL_BASE
    end

    def self.understand?(type)
      %w[packaging.neon.kde.org.uk packaging.neon.kde.org
         git.neon.kde.org anongit.neon.kde.org].include?(type)
    end

    private

    def split_entry(entry)
      parts = entry.split('/')
      name = parts[-1]
      component = parts[0..-2].join('_') || 'neon'
      [name, component]
    end

    def params(str)
      # FIXME: branch hardcoded!!@#!$%!!
      # FIXME: also in debian
      # FIXME: also in github
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
        return @listing if defined?(@listing) # Cache in class scope.
        out, _err = TTY::Command.new(printer: :null)
                                .run('ssh neon@git.neon.kde.org')
        listing = out.chop.split($/)
        listing.shift # welcome message leading, drop it.
        @listing = listing.collect do |entry|
          entry.split[-1]
        end.uniq.compact.freeze
      end
    end
  end
end
