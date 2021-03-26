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

require_relative '../lib/aptly-ext/remote'
require_relative '../lib/ci/pattern'

options = OpenStruct.new
options.repos = nil
options.all = false
options.distribution = nil

# Run aptly snapshot on given DIST eg: netrunner-desktop-next.
class DCISnapshot
  def initialize
    @snapshots = []
    @repos = []
    @components = []
    @type = ''
    @dist = ''
    @versioned_dist = ''
    @currentdist = {}
    @version = ''
    @arch = []
    @stamp = DateTime.now.strftime("%Y%m%d.%H%M")
    @log = Logger.new(STDOUT).tap do |l|
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
    file = ENV['WORKSPACE'] + '/data/dci/dci.image.yaml'
    data = load(file)
    raise unless data.is_a?(Hash)

    data
  end

    def type
    @type = ENV['FLAVOR']
    @type
  end

  def distribution
    type()
    @dist = 'netrunner-' + @type
    @dist
  end

  def version
    @version = ENV['VERSION']
    @version
  end

  def versioned_dist
    self.distribution()
    self.version()
    @versioned_dist = @dist + '-' + @version
    @versioned_dist
  end

  def currentdist
    type = self.type()
    dist = self.distribution()
    data = self.config()
    currentdist = data[type]
    @currentdist = currentdist[dist]
    @currentdist
  end

  def components
    data = self.currentdist()
    components = data[:components]
    @components = components.split(",")
    @components
  end

  def repo_array
    version
    data = self.components()
    data.each do |x|
      ver_repo = x + '-' + @version
      @repos << ver_repo
    end
    raise unless @repos.is_a?(Array)
    @repos
  end

  def arch_array
    data = self.currentdist()
    arch =  data[:architecture]
    @arch << arch
    @arch << 'i386'
    @arch << 'all'
    @arch << 'source'
    raise unless @arch.is_a?(Array)
    @arch
  end

  def aptly_options
    self.versioned_dist()
    self.arch_array()
    opts = {}
    opts[:Distribution] = @versioned_dist
    opts[:Architectures] = @arch
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    opts
  end

  def snapshot_repo
    self.repo_array()
    opts = self.aptly_options()
    Faraday.default_connection_options =
      Faraday::ConnectionOptions.new(timeout: 40 * 60 * 60)
    Aptly::Ext::Remote.dci do
      @repos.each do |repo_name|
        repo = Aptly::Repository.get(repo_name)
        @log.info "Phase 1: Snapshotting #{repo.Name}"
        puts repo.packages
        puts repo.DefaultComponent
        snapshot =
          if repo.packages.empty?
            Aptly::Snapshot.create(
              "#{repo.Name}_#{@versioned_dist}_#{@stamp}", opts
            )
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
    opts = self.aptly_options()
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
