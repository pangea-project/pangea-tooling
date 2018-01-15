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
require 'net/ssh'

require_relative '../lib/aptly-ext/filter'
require_relative '../lib/nci' # nci config module
require_relative '../../lib/aptly-ext/remote'

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
    clean_db
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
    keep = Aptly::Ext::LatestVersionFilter.filter(sources, @keep_amount)
    (sources - keep).each { |x| delete_source(x) }
  end

  def clean_binaries
    keep = Aptly::Ext::LatestVersionFilter.filter(binaries, @keep_amount)
    (binaries - keep).each { |x| delete_binary(x) }
    keep.each { |x| delete_binary(x) unless bin_has_source?(x) }
  end

  def clean_db
    Net::SSH.start('racnoss.kde.org', 'neonarchives') do |ssh|
      ssh.exec!(
        'XDG_RUNTIME_DIR=/run/user/`id -u` \
        systemctl --user start aptly_db_cleanup'
      )
    end
  end

  def source_name_and_version_for(package)
    name = package.Package
    version = package.Version
    if package.Source
      source = package.Source
      match = source.match(/^(?<name>[^\s]+)( \((?<version>[^\)]+)\))?$/)
      name = match[:name]
      # Version can be nil, handle this correctly.
      version = match[:version] || version
    end
    [name, version]
  end

  def bin_has_source?(bin)
    package = Aptly::Ext::Package.get(bin)
    name, version = source_name_and_version_for(package)
    sources.any? { |x| x.name == name && x.version == version }
  end

  def sources
    @sources ||= @repo.packages(q: '$Architecture (source)')
                      .compact
                      .uniq
                      .collect do |key|
                        Aptly::Ext::Package::Key.from_string(key)
                      end
  end

  def binaries
    @binaries ||= @repo.packages(q: '!$Architecture (source)')
                       .compact
                       .uniq
                       .collect do |key|
                         Aptly::Ext::Package::Key.from_string(key)
                       end
  end

  def delete_source(source_key)
    sources.delete(source_key)
    query = format('$Source (%s), $SourceVersion (%s)',
                   source_key.name,
                   source_key.version)
    binaries = @repo.packages(q: query)
    delete([source_key.to_s] + binaries)
  end

  def delete_binary(key)
    binaries.delete(key)
    delete(key.to_s)
  end

  def delete(keys)
    puts "@repo.delete_packages(#{keys})"
    @repo.delete_packages(keys)
  end
end

# Helper to construct repo names
class RepoNames
  def self.all(prefix)
    NCI.series.collect { |name, _version| "#{prefix}_#{name}" }
  end
end

if $PROGRAM_NAME == __FILE__ || ENV.include?('PANGEA_TEST_EXECUTION')
  # SSH tunnel so we can talk to the repo
  Faraday.default_connection_options =
    Faraday::ConnectionOptions.new(timeout: 15 * 60)
  Aptly::Ext::Remote.neon do
    RepoCleaner.clean(%w[unstable stable] +
                      RepoNames.all('unstable') + RepoNames.all('stable'))
    RepoCleaner.clean(RepoNames.all('release'), keep_amount: 4)
    RepoCleaner.clean(RepoNames.all('release-lts'), keep_amount: 4)
  end
end
