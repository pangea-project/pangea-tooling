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

require_relative '../lib/debian/version'

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
    # FIXME: maybe should be called hash?
    attr_reader :uid

    def self.from_string(str)
      match = REGEX.match(str)
      unless match
        raise ArgumentError, "String doesn't appear to match our regex: #{str}"
      end
      kwords = Hash[match.names.map { |name| [name.to_sym, match[name]] }]
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

# Cleans up an Aptly::Repository by removing all versions of source+bin that
# are older than the newest version.
class RepoCleaner
  def initialize(repo, keep_amount:)
    @repo = repo
    @keep_amount = keep_amount
  end

  # Iterate over each source. Sort its versions and drop lowest ones.
  def clean
    clean_sources
    clean_binaries
    @repo.published_in(&:update!)
  end

  def self.clean(repo_whitelist = [], keep_amount: 1)
    Aptly::Repository.list.each do |repo|
      next unless repo_whitelist.include?(repo.Name)
      RepoCleaner.new(repo, keep_amount: keep_amount).clean
    end
  end

  private

  def clean_sources
    sources_hash.each do |_name, names_packages|
      delete?(names_packages) do |key|
        delete_source(key)
      end
    end
  end

  def clean_binaries
    binaries_hash.each do |_name, names_packages|
      delete?(names_packages) do |key|
        delete_binary(key)
      end
    end
  end

  def delete?(names_packages)
    versions = debian_versions(names_packages).sort.to_h
    # For each version get the relevant keys and drop the keys until
    # we have sufficiently few versions remaining
    while versions.size > @keep_amount
      _, keys = versions.shift
      keys.each do |source_key|
        yield source_key
      end
    end
  end

  def sources
    @sources ||= @repo.packages(q: '$Architecture (source)')
                      .compact
                      .uniq
                      .collect { |key| Package::Key.from_string(key) }
  end

  def binaries
    @binaries ||= @repo.packages(q: '!$Architecture (source)')
                       .compact
                       .uniq
                       .collect { |key| Package::Key.from_string(key) }
  end

  # Group the sources in a Hash by their name attribute, so we can process
  # one source at a time.
  def sources_hash
    @sources_hash ||= sources.group_by(&:name)
  end

  # Group the binaries in a Hash by their name attribute, so we can process
  # one source at a time.
  def binaries_hash
    @binaries_hash ||= binaries.group_by(&:name)
  end

  # Group the keys in a Hash by their version. This is so we can easily
  # sort the versions.
  def debian_versions(names_packages)
    # Group the keys in a Hash by their version. This is so we can easily
    # sort the versions.
    versions = names_packages.group_by(&:version)
    # Pack them in a Debian::Version object for sorting
    Hash[versions.map { |k, v| [Debian::Version.new(k), v] }]
  end

  def delete_source(source_key)
    query = format('$Source (%s), $SourceVersion (%s)',
                   source_key.name,
                   source_key.version)
    binaries = @repo.packages(q: query)
    delete([source_key.to_s] + binaries)
  end

  def delete_binary(key)
    delete(key)
  end

  def delete(keys)
    puts "@repo.delete_packages(#{keys})"
    @repo.delete_packages(keys)
  end
end

if __FILE__ == $PROGRAM_NAME || ENV.include?('PANGEA_TEST_EXECUTION')
  # SSH tunnel so we can talk to the repo
  gateway = Net::SSH::Gateway.new('drax', 'root')
  gateway_port = gateway.open('localhost', 9090)

  Aptly.configure do |config|
    config.host = 'localhost'
    config.port = gateway_port
  end

  RepoCleaner.clean(%w(unstable stable))
end
