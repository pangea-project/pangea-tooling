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

# Run aptly snapshot on given DIST eg: netrunner-desktop-next.
class DCISnapshot
  def initialize
    @image_data = {}
    @snapshots = []
    @repos = []
    @components = []
    @release_type = ''
    @type_data = {}
    @series = ''
    @release = ''
    @currentdist = {}
    @series = ''
    @arch = ''
    @arch_array = []
    @arm_board = nil
    @stamp = DateTime.now.strftime("%Y%m%d.%H%M")
    @log = Logger.new($stdout).tap do |l|
      l.progname = 'snapshotter'
      l.level = Logger::INFO
    end
  end

  def load(file)
    hash = {}
    hash.deep_merge!(YAML.load(File.read(File.expand_path(file))))
    hash
  end

  def config
    file = File.expand_path("#{__dir__}/../data/dci/dci.image.yaml")
    @image_data = load(file)
    raise unless @image_data.is_a?(Hash)

    @image_data
  end

  def release_types
    config
    @release_types = @image_data.keys
  end

  def release_type
    @release_type = ENV['RELEASE_TYPE']
  end

  def type_data
    config
    release_type
    @type_data = @image_data[@release_type]
  end

  def arm_board
    @arm_board = ENV['ARM_BOARD']
  end

  def release
    release_type
    arm_board
    @release = @arm_board ? "netrunner-#{@release_type}-#{@arm_board}" : "netrunner-#{@release_type}"
  end

  def series
    @series = ENV['SERIES']
  end

  def series_release
    release
    series
    @series_release = "#{@release}-#{@series}"
  end

  def currentdist
    config
    release_type
    type_data
    release
    @currentdist = @type_data[@release]
    @currentdist
  end

  def arch
    release_type
    release
    @arch = DCI.arch_by_release(DCI.get_release_data(@release_type, @release))
  end

  def components
    release_type
    release
    @components = DCI.components_by_release(DCI.get_release_data(@release_type, @release))
  end

  def aptly_components_to_repos
    series
    components
    @components.each do |x|
      repo = x + '-' + @series
      @repos << repo
    end
    raise unless @repos.is_a?(Array)
    @repos
  end

  def arch_array
    arch
    @arch_array << @arch
    @arch_array << 'i386'
    @arch_array << 'all'
    @arch_array << 'source'
    raise unless @arch_array.is_a?(Array)
    @arch_array
  end

  def aptly_options
    series_release
    arch_array
    opts = {}
    opts[:Distribution] = @series_release
    opts[:Architectures] = @arch_array
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    opts
  end

  def snapshot_repo
    aptly_components_to_repos
    opts = aptly_options
    Faraday.default_connection_options =
      Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
    Aptly::Ext::Remote.dci do
      @repos.each do |repo_name|
        repo = Aptly::Repository.get(repo_name)
        @log.info "Phase 1: Snapshotting repo: #{repo.Name} with packages: #{repo.packages}"
        puts repo.DefaultComponent
        snapshot =
          if repo.packages.empty?
            Aptly::Snapshot.create(
              "#{repo.Name}_#{@series_release}_#{@stamp}", opts
            )
          else
            # component = repo.Name.match(/(.*)-netrunner-backports/)[1].freeze
            repo.snapshot("#{repo.Name}_#{@series_release}_#{@stamp}", opts)
          end
        snapshot.DefaultComponent = repo.DefaultComponent
        @snapshots << snapshot
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
          (x.Distribution == opts[:Distribution]) && (x.Prefix == 'netrunner')
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
