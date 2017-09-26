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

require 'logger'
require 'logger/colors'

require_relative 'data'
require_relative 'repository'

module NCI
  module DebianMerge
    # Conducts a mere into Neon/pending-merge
    class Merger
      def initialize
        @data = Data.from_file
        @log = Logger.new(STDERR)
        @failed_merges = {}
      end

      def run
        repos = merge_repos(Dir.pwd)
        debug_failed_merges
        raise unless @failed_merges.empty?
        repos.each do |r|
          @log.info "Pushing #{r.url}"
          r.push
        end
      end

      # kind of private bits

      def debug_failed_merges
        @failed_merges.each do |url, error|
          @log.error url
          @log.error error
          @log.error error.backtrace
        end
      end

      def merge(url, tmpdir)
        @log.info "Cloning #{url}"
        repo = Repository.clone_into(url, tmpdir)
        repo.tag_base = @data.tag_base
        @log.info "Merging #{url}"
        repo.merge
        repo
      rescue => e
        @failed_merges[url] = e
      end

      def merge_repos(tmpdir)
        @data.repos.collect do |url|
          merge(url, tmpdir)
        end
      end
    end
  end
end

# :nocov:
$stdout = STDERR
NCI::DebianMerge::Merger.new.run if $PROGRAM_NAME == __FILE__
# :nocov:
