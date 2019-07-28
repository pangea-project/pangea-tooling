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
require 'thwait'
require 'logger'
require 'logger/colors'
require 'set'
require 'pp'
require 'deep_merge'
require 'yaml'

require_relative '../../lib/aptly-ext/remote'
require_relative '../lib/ci/pattern'

options = OpenStruct.new
options.repos = nil
options.all = false
options.distribution = nil

#Run aptly snapshot on given DIST eg: netrunner-desktop-next.
class DCISnapshot
  def initialize(dist, ver)
    @dist = dist
    @snapshots = []
    @repos = []
    @components = []
    @version = ver
    @versioned_dist = dist + '-' + ver
    @stamp = DateTime.now.strftime("%Y%m%d.%H%M")
    @log = Logger.new(STDOUT).tap do |l|
      l.progname = 'snapshotter'
      l.level = Logger::INFO
    end
  end

  def load(file)
    hash = {}
    hash.deep_merge!(YAML.load(File.read(File.expand_path(file))))
    #hash = CI::IncludePattern.convert_hash(hash, recurse: false)
    hash
  end

  def config
    file = File.expand_path("#{__dir__}/../../data/dci/dci.image.yaml")
    data = load(file)
    raise unless data.is_a?(Hash)

    data
  end

  def components
    components = []
    data = config
    current_dist = data.select { |dist, options| dist.include? @dist }
    current_dist.each do |_dist, v|
      components = v[:components].split(',')
    end
    components
  end

  def repo_array
    data = components
    data.each do |x|
      ver_repo = x + '-' + @version
      @repos << ver_repo
    end
    @repos
  end

  def arch_array
    arch = []
    data = config
    current_dist = data.select { |dist, options| dist.include? @dist }
    current_dist.each do |_dist, v|
      arch = v[:architectures]
    end
    arch
  end

  def snapshot_repo
    repo_array
    arches = arch_array
    arches << 'all'
    arches << 'source'
    Faraday.default_connection_options =
      Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
    Aptly::Ext::Remote.dci do
      opts = {}
      opts[:Distribution] = @versioned_dist
      opts[:Architectures] = arches
      opts[:ForceOverwrite] = true
      opts[:SourceKind] = 'snapshot'

      @repos.each do |repo_name|
        repo = Aptly::Repository.get(repo_name)
        @log.info "Phase 1: Snapshotting #{repo.Name}"
        puts repo.packages
        puts repo.DefaultComponent
        snapshot =
          if repo.packages.empty?
            Aptly::Snapshot.create("#{repo.Name}_#{@versioned_dist}_#{@stamp}", opts)
          else
            # component = repo.Name.match(/(.*)-netrunner-backports/)[1].freeze
            repo.snapshot("#{repo.Name}_#{@versioned_dist}_#{@stamp}", opts)
          end
        snapshot.DefaultComponent = repo.DefaultComponent
        @snapshots << snapshot
        @log.info 'Phase 1: Snapshotting complete'
      end
    end
  end

  def publish_snapshot
    @log.info 'Phase 2: Publishing of snapshots'
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
      @log.info("Snapshots published")
    elsif @s3.count == 1
      pubd = @s3[0]
      pubd.update!(Snapshots: @sources, ForceOverwrite: true)
      @log.info("Snapshots updated")
    end
  end
end

version = ENV['VERSION']
dist = ENV['DIST']

s = DCISnapshot.new(dist, version)
s.snapshot_repo
s.publish_snapshot
#     @snapshots = []
#     @repos = []
#     @components = []
#
#     component_config_file =
#                 "#{File.expand_path(File.dirname(__FILE__))}/data/dci/dci.image.yaml"
#
#
#     if File.exist? component_config_file
#       components_config = YAML.load_stream(File.read(component_config_file))
#       components_config.each do |component_config|
#         component_config.each do |flavor, v|
#           if flavor =~ DIST
#             @components < v[:components]
#             puts @components
#             @components.each do |component|
#               versioned_repo = component + '-' + DIST
#               @repos < versioned_repo
#             end

#             puts opts
#             puts @repos
#           else
#             next
#           end
#           @repos.each do |repo|
#             puts repo
#         #   @log.info "Phase 1: Snapshotting #{repo.Name}"
#         #   snapshot =
#         #     if repo.packages.empty?
#         #       Aptly::Snapshot.create("#{repo.Name}_#{options.distribution}_#{stamp}", opts)
#         #     else
#         #       # component = repo.Name.match(/(.*)-netrunner-backports/)[1].freeze
#         #       repo.snapshot("#{repo.Name}_#{options.distribution}_#{stamp}", opts)
#         #     end
#         #   snapshot.DefaultComponent = repo.DefaultComponent
#         #   @snapshots << snapshot
#         #   @log.info 'Phase 1: Snapshotting complete'
#         #   end
#         #
#         # @log.info 'Phase 2: Publishing of snapshots'
#         # @sources = @snapshots.collect do |snap|
#         #   { Name: snap.Name, Component: snap.DefaultComponent }
#         # end
#         #
#         # @s3 = Aptly::PublishedRepository.list.select do |x|
#         #   !x.Storage.empty? && (x.SourceKind == 'snapshot') &&
#         #     (x.Distribution == opts[:Distribution]) && (x.Prefix == 'netrunner')
#         # end
#         #
#         # if @s3.empty?
#         #   puts @sources
#         #   Aptly.publish(@sources, 's3:ds9-eu:netrunner', 'snapshot', opts)
#         #   @log.info("Snapshots published")
#         # elsif @s3.count == 1
#         #   pubd = @s3[0]
#         #   pubd.update!(Snapshots: @sources, ForceOverwrite: true)
#         #   @log.info("Snapshots updated")
#         # end
#           end
#         end
#       end
#     end
# end
