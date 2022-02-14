#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
# Copyright (C) 2019 Scarlett Moore <sgmoore@kde.org>
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

require 'aptly'
require 'ostruct'
require 'uri'
require 'date'
require 'logger'
require 'logger/colors'
require 'set'
require 'pp'
require 'deep_merge'
require 'yaml'
require 'fileutils'

require_relative '../lib/dci'
require_relative '../lib/aptly-ext/remote'
require_relative '../lib/ci/pattern'
require_relative '../lib/os'

# Run aptly snapshot on given distribution eg: netrunner-desktop-next.
class DCISnapshot
  def initialize
    @image_data = DCI.all_image_data
    @release_type = ENV.fetch('RELEASE_TYPE')
    @series = ENV.fetch('SERIES')
    @release = ENV.fetch('RELEASE')
    @release_data = DCI.get_release_data(@release_type, @release)
    @components = DCI.release_components(@release_data)
    @arch = DCI.arch_by_release(@release_data)
    @arm_board = DCI.arm_board_by_release(@release_data)
    @release_distribution = DCI.release_distribution(@release, @series)
    @arch_array = []
    @aptly_snapshot = {}
    @snapshots = []
    @repos = DCI.series_release_repos(@series, @components)
    @repo = ''
    @prefix = DCI.aptly_prefix(@release_type)
    @stamp = DateTime.now.strftime("%Y%m%d.%H%M")
    @snapshot = @series + '-21122'
    @log = Logger.new($stdout).tap do |l|
      l.progname = 'snapshotter'
      l.level = Logger::INFO
    end
  end

  def arch_array
    @arch_array << @arch
    @arch_array << 'i386'
    @arch_array << 'all'
    @arch_array << 'source'
    raise unless @arch_array.is_a?(Array)
    @arch_array
  end

  def aptly_options
    arch_array
    opts = {}
    opts[:Distribution] = @release_distribution
    opts[:Architectures] = arch_array
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    opts
  end

  def snapshot_repo
    opts = aptly_options
    Faraday.default_connection_options =
      Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
    Aptly::Ext::Remote.dci do
      @repos.each do |repo_name|
        @repo = Aptly::Repository.get(repo_name)
        @log.info "Phase 1: Snapshotting repo: #{@repo.Name} with packages: #{@repo.packages}"

        if @repo.packages.empty?
          @aptly_snapshot = Aptly::Snapshot.create("#{@repo.Name}_#{@release_distribution}_#{@stamp}", opts)
        else
          @aptly_snapshot = @repo.snapshot("#{@repo.Name}_#{@release_distribution}_#{@stamp}", opts)
        end
        @aptly_snapshot.DefaultComponent = @repo.DefaultComponent
        @snapshots << @aptly_snapshot
        @log.info 'Phase 1: Snapshotting complete'
      end
    end
  end

  def publish_snapshot
    opts = aptly_options
    @log.info 'Phase 2: Publishing of snapshots'
    Faraday.default_connection_options =
      Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
    Aptly::Ext::Remote.dci do
      @sources = @snapshots.collect do |snap|
        puts snap
        { Name: snap.Name, Component: snap.DefaultComponent }
      end
      @s3 = Aptly::PublishedRepository.list.select do |x|
        !x.Storage.empty? && (x.SourceKind == 'snapshot') &&
          (x.Distribution == opts[:Distribution]) && (x.Prefix == @prefix)
      end
      puts @s3
      if @s3.empty?
        Aptly.publish(@sources, 's3:ds9-eu:netrunner', 'snapshot', opts)
        @log.info('Snapshots published')
      elsif @s3.count == 1
        pubd = @s3[0]
        pubd.update!(Snapshots: @sources, ForceOverwrite: true)
        @log.info('Snapshots updated')
      end
    end
  end
end



# :nocov:
if $PROGRAM_NAME == __FILE__
  s = DCISnapshot.new
  s.snapshot_repo
  s.publish_snapshot
end
# :nocov:
