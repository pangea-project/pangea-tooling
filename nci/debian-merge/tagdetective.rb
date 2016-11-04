#!/usr/bin/env ruby
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

require 'git'
require 'json'
require 'logger'
require 'logger/colors'
require 'tmpdir'

require_relative '../../ci-tooling/lib/projects/factory/neon'

# Finds latest tag of ECM and then makes sure all other frameworks
# have the same base version in their tag (i.e. the tags are consistent)
module NCI
  module DebianMerge
    class TagDetective
      ORIGIN = 'origin/master'.freeze
      ECM = 'frameworks/extra-cmake-modules'.freeze
      EXCLUSION = %w(frameworks/prison frameworks/kactivities frameworks/purpose
                     frameworks/syntax-highlighting).freeze

      def initialize
        @log = Logger.new(STDOUT)
      end

      def list_frameworks
        @log.info 'listing frameworks'
        ProjectsFactory::Neon.ls.select do |x|
          x.start_with?('frameworks/') && !EXCLUSION.include?(x)
        end
      end

      def frameworks
        @frameworks ||= list_frameworks.collect do |x|
          File.join(ProjectsFactory::Neon.url_base, x)
        end
      end

      def last_tag_base
        @last_tag_base ||= begin
          @log.info 'finding latest tag of ECM'
          ecm = frameworks.find { |x| x.include?(ECM) }
          raise unless ecm
          Dir.mktmpdir do |tmpdir|
            git = Git.clone(ecm, tmpdir)
            last_tag = git.describe(ORIGIN, tags: true, abbrev: 0)
            last_tag.reverse.split('-', 2)[-1].reverse
          end
        end
      end

      def investigation_data
        # TODO: this probably should be moved to Data class
        data = {}
        data[:tag_base] = last_tag_base
        data[:repos] = frameworks.each do |url|
          validate(url)
        end
        data
      end

      def validate(url)
        @log.info "checking if tag matches on #{url}"
        valid = Git.ls_remote(url).fetch('tags').keys.any? do |x|
          x.start_with?(last_tag_base)
        end
        raise "found no #{last_tag_base} tag in #{url}" unless valid
        @log.info " looking good #{url}"
      end

      def run
        File.write('data.json', JSON.generate(investigation_data))
      end
      alias investigate run
    end
  end
end

# :nocov:
NCI::DebianMerge::TagDetective.new.run if __FILE__ == $PROGRAM_NAME
# :nocov:
