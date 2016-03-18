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

require 'aptly'
require 'net/ssh/gateway'

# SSH tunnel so we can talk to the repo
gateway = Net::SSH::Gateway.new('drax', 'root')
gateway.open('localhost', 9090, 9090)

Aptly.configure do |config|
  config.host = 'localhost'
  config.port = 9090
end

class Package
  # A package short key (key without uid)
  # e.g.
  # "Psource kactivities-kf5 5.18.0+git20160312.0713+15.10-0"
  class ShortKey
    attr_reader :architecture
    attr_reader :name
    attr_reader :version

    private

    def initialize(architecture:, name:, version:)
      @architecture = architecture
      @name = name
      @version = version
    end

    def to_s
      "P#{@architecture} #{@name} #{@version}"
    end
  end

  # A package key
  # e.g.
  # "Psource kactivities-kf5 5.18.0+git20160312.0713+15.10-0 8ebad520d672f51c"
  class Key < ShortKey
    attr_reader :uid

    def self.from_string(str)
      match = REGEX.match(str)
      kwords = Hash[regex.names.map { |name| [name.to_sym, match[name]] }]
      new(**kwords)
    end

    def to_s
      "#{super} #{@uid}"
    end

    private

    REGEX = /
      ^
      P(?<architecture>[^\s]+)
      \s
      (?<name>[^\s]+)
      \s
      (?<version>[^\s]+)
      \s
      (?<uid>[^\s]+)
      $
    /x

    def initialize(architecture:, name:, version:, uid:)
      super(architecture: architecture, name: name, version: version)
      @uid = uid
    end
  end
end

require_relative '../lib/debian/version'

class Query
  class Field
    OPERATORS = {
      :== => '=',
      :>= => '<=',
      :<= => '<=',
      :>> => '>>',
      :<< => '<<',
      :% => '%',
      :~ => '~'
    }.freeze

    attr_reader :str

    def initialize(query)
      @query = query
      @str = ''
    end

    def ==(other)
      @str += format(' (= %s)', other)
      @query
    end

    def method_missing(name, *args)
      return super unless args.size == 1
      other = args.shift
      @str += " (#{OPERATORS.fetch(name)} #{other})"
      @query
    end
  end

  DOLLAR_PREFIX = %i(
    Source
    SourceVersion
    Architecture
    Version
    PackageType).freeze

  def initialize
    @str = ''
    @pending_field = nil
  end

  def names
    @names ||= Hash[DOLLAR_PREFIX.map { |p| [p, "$#{p}"] }]
  end

  def method_missing(name, *args)
    return super unless name.to_s[0].upcase == name.to_s[0]
    @str += names.fetch(name, name.to_s)
    @pending_field = Field.new(self)
  end

  def and
    close
    @str += ', '
    self
  end

  def close
    if @pending_field
      @str += @pending_field.str
      @pending_field = nil
    end
    self
  end

  def to_s
    close
    @str
  end
end

def query(&block)
  yield query = Query.new
  query.close
end

# p query { |x|
#   x.Source.==('name')
#    .and.SourceVersion.==('1')
#    .and.Kitten.~('autogram')
# }.to_s
#
# exit

Aptly::Repository.list.each do |repo|
  next unless repo.Name == 'unstable' || repo.Name == 'stable'

  packages = repo.packages(q: '$Architecture (source)').compact.uniq

  packages.collect! { |key| Package::Key.from_string(key) }
  package_hash = packages.group_by(&:name)
  package_hash.each do |_, names_packages|
    versions = names_packages.group_by(&:version)
    versions = Hash[versions.map { |k, v| [Debian::Version.new(k), v] }]
    versions = versions.sort.to_h
    while versions.size > 1
      _, keys = versions.shift
      keys.each do |key|
        query = format('$Source (%s), $SourceVersion (%s)',
                       key.name,
                       key.version)
        binaries = repo.packages(q: query)
        repo.delete_package(key.to_s)
        repo.delete_packages(binaries)
      end
    end
  end

  repo.published_in(&:update!)
end
