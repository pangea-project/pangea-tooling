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
# License along with this library.  If not, see <http://www.gnu.org/licenses/>

# rubocop:disable all

Thread.abort_on_exception = true

require 'json'
require 'yaml'
require 'open-uri'
require 'ostruct'

require_relative 'dep_builder/apt_file'

Project = Struct.new(:name, :component, :deps, :dependees)

# TODO: to map this you need to know the name of the cmake project which
# we currently do not print on error making this harder than it needs to be
static_map = YAML.load(File.read("#{__dir__}/dep_builder/static_map.yml"))
finder_map = YAML.load(File.read("#{__dir__}/dep_builder/finder_map.yml"))

# ----------- BoostPython
# - got no match on FindBoostPython.cmake
# - got no match on modules/FindBoostPython.cmake
# - got no match on cmake/modules/FindBoostPython.cmake
# - got no match on kig_stable_qt5/cmake/modules/FindBoostPython.cmake
# - got no match on workspace/kig_stable_qt5/cmake/modules/FindBoostPython.cmake
# - got no match on jenkins/workspace/kig_stable_qt5/cmake/modules/FindBoostPython.cmake
# - got no match on srv/jenkins/workspace/kig_stable_qt5/cmake/modules/FindBoostPython.cmake
# - got no match on /srv/jenkins/workspace/kig_stable_qt5/cmake/modules/FindBoostPython.cmake
# align-dependencies.rb:176:in `block (3 levels) in <main>': Could not find concrete match (RuntimeError)

projects = []

temps = ARGV unless ARGV.empty?

file_cache = {}

require 'concurrent'


class FutureObserver
  def initialize
    @futures = []
    @observations = Concurrent::Array.new
  end

  def update(time, value, reason)
    p [time, value, reason]
    @observations << value
  end

  def observe(future)
    @futures << future
    future.add_observer(self)
  end

  def wait_for_all
    until @futures.all? { |x| x.fulfilled? || x.rejected? } do
      sleep 5
    end
    p @observations.uniq
  end
end
obi = FutureObserver.new

class Overrides
  def initialize
    @overrides = YAML.load(File.read("#{__dir__}/dep_builder/finder_map.yml"))
  end

  def match(path)
    @overrides.fetch(path, nil)
  end
end

module Contents
  require 'forwardable'

  class Connection
    extend Forwardable

    BASE_URL = 'https://contents.neon.kde.org/v1'.freeze

    def initialize
      require 'faraday'
      require 'logger'
      require 'json'
      @connection = Faraday.new(url: BASE_URL) do |c|
        c.request :url_encoded
        c.response :logger, ::Logger.new(STDOUT), bodies: true
        c.adapter Faraday.default_adapter
      end
    end

    def_delegators :@connection, :get
  end

  class APIObject
    def initialize(connection)
      @connection = connection
    end
  end

  class Archive < APIObject
    attr_reader :id

    def initialize(id, connection = Connection.new)
      super(connection)
      @id = id
    end

    def find(pattern)
      resp = @connection.get("find/#{id}") { |req| req.params['q'] = pattern }
      JSON.parse(resp.body)
    end

    alias_method :to_s, :id
  end

  module_function

  def pools(connection = Connection.new)
    resp = connection.get('pools')
    pools = JSON.parse(resp.body)
    pools.inject({}) do |memo, (k, v)|
      memo[k] = v.collect { |x| Archive.new(x, connection) }
      memo
    end
  end

  def neon_archives(connection = Connection.new)
    pools.fetch('neon')
  end
end

class ContentsResolver
  def self.find(pattern)
    Contents.neon_archives.each do |archive|
      results = archive.find("*#{pattern}")
      packages = results.values.flatten.uniq
      return packages unless packages.empty?
    end
    []
  end
end

class Resolver
  class << self
    def file_cache
      @file_cache ||= Concurrent::Hash.new
    end
  end

  def initialize(path)
    @path = path
    @overrides = Overrides.new
  end

  def resolve
    p @path
    self.class.file_cache[@path] ||= begin
      r = resolve_internal
      r = "NoResolve#{@path}" unless r
      r
    end
  end

  private

  def resolve_internal
    # FIXME: meh?
    apt_file = Apt::File.new(sources_list: "/home/me/src/git/pangea-tooling/meta-dep/sources.list",
                             cache_dir: "/home/me/src/git/pangea-tooling/meta-dep/apt-file-cache")


    # This is a very special loop. It constantly pops one part of the path
    # until the path is only /, t
    path_parts = []
    possible_path_parts = @path.split('/')
    until possible_path_parts.empty?
      path_parts.unshift(possible_path_parts.pop)
      path = path_parts.join('/')

      override = @overrides.match(path)
      return override if override

      begin
        # packages = apt_file.search(path).lines
        p packages = ContentsResolver.find(path)
      rescue RuntimeError => e
        puts "   - got no match on #{path} via apt-file ... giving up."
        puts e
        next
      end

      if packages.size < 1
        p packages
        puts "failed to resolve #{path}"
        raise
      end

      # packages.collect! do |entry|
      #   entry.split(':')[0]
      # end

      if packages.size > 1
        if packages.include?('cmake-data')
          # CMake always wins.
          # FIXME: possibly project should factor into the cmake winning, if project contains KF5 it probably should not win
          # FIXME: static_map should override this
          packages = ['cmake']
        end
        if packages.include?('qtbase5-dev') && packages.include?('qtbase5-gles-dev')
          # qtbase5-gles-dev in xenial proper is bugged like hell and contains
          # pretty much all the rubbish that should be in qtbase. So always
          # resolve this in favor of qtbase5.
          packages = ['qtbase5-dev']
        end
        if packages.include?('libkf5kdelibs4support-dev') && packages.include?('kdelibs5-dev')
          packages = ['libkf5kdelibs4support-dev']
        end
      end

      if packages.size > 1
        puts "   - couldn't find absolute match on #{path}"
        # FIXME: due to apt-file this can occur when we have excess
        # repos enabled, so it might be wise to try again with only
        # neon enabled?
        # or... do a two-pass resolution first with only neon, then with
        # neon and ubuntu. that way neon will resolve what it can regardless
        # of what is in ubuntu
        p packages
        next
      end

      # Force cmake rather than cmake-data for consistency reasons.
      packages[0] = 'cmake' if packages[0] == 'cmake-data'
      packages[0] = 'libphonon4qt5-dev, libphonon4qt5experimental-dev' if packages[0] == 'libphonon4qt5-dev'
      return packages[0]
    end
    nil
  end
end

dep_dir = 'meta-dep'
Dir.mkdir(dep_dir) unless File.exist?(dep_dir)
Dir.chdir(dep_dir) do
  File.write('sources.list', DATA.read)
  Dir.mkdir('apt-file-cache') unless Dir.exist?('apt-file-cache')
  apt_file = Apt::File.new(sources_list: "#{Dir.pwd}/sources.list",
                           cache_dir: "#{Dir.pwd}/apt-file-cache")
  apt_file.update

  File.delete('dependency-metadata.tar.xz') if File.exist?('dependency-metadata.tar.xz')
  `wget http://build.kde.org/userContent/dependency-metadata.tar.xz`
  `tar -xf dependency-metadata.tar.xz`
  Dir.glob('*-kf5-qt5.json').each do |jsonFile|
    # FIXME: parser is fucked with missing deps
    # FIXME: qt5 parse entirely useless

    project = Project.new
    project.name = jsonFile.gsub('-kf5-qt5.json', '')
    project.deps = []

    next unless temps.include?(project.name)

    data = File.read(jsonFile)
    json = JSON.parse(data, object_class: OpenStruct)
    json.each do |dependency|
      next unless dependency.explicit
      puts "----------- #{dependency.project}"
      dependency.files.each do |file|
        # future = Concurrent::Future.new {
           Resolver.new(file).resolve
        #   }
        # obi.observe(future)
        # future.execute
      end
    end
  end
end

obi.wait_for_all
