#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/aptly-ext/remote'
require_relative '../ci-tooling/lib/nci'

# NB: in publish prefixes _ is replaced by / on the server, to get _ you need
#   to use __

def repo(label_type:, series:, **kwords)
  {
    Distribution: series,
    Origin: 'neon',
    Label: format('KDE neon - %s', label_type),
    Architectures: %w[source i386 amd64 armhf arm64 armel all]
  }.merge(kwords)
end

PublishingRepo = Struct.new(:repo_name, :publish_name)

repos = {}

NCI.series.each_key do |series|
  repos.merge!(
    PublishingRepo.new("unstable_#{series}", 'dev_unstable') =>
      repo(label_type: 'Dev Unstable Edition', series: series),
    PublishingRepo.new("stable_#{series}", 'dev_stable') =>
      repo(label_type: 'Dev Stable Edition', series: series),
    PublishingRepo.new("release_#{series}", 'release') =>
      repo(label_type: 'User Edition', series: series),
    PublishingRepo.new("release-lts_#{series}", 'release_lts') =>
      repo(label_type: 'User Edition (LTS)', series: series),
    PublishingRepo.new("testing_#{series}", 'testing') =>
      repo(label_type: 'User Edition (LTS)', series: series)
  )
end

require 'pp'
pp repos

Aptly::Ext::Remote.neon do
  repos.each do |publishing_repo, repo_kwords|
    next if Aptly::Repository.exist?(publishing_repo.repo_name)
    warn "repo = Aptly::Repository.create(#{publishing_repo.repo_name})"
    warn "repo.publish(#{publishing_repo.publish_name || publishing_repo.repo_name}, #{repo_kwords})"
    repo = Aptly::Repository.create(publishing_repo.repo_name)
    repo.publish(publishing_repo.publish_name || publishing_repo.repo_name,
                 **repo_kwords)
  end

  # Cleanup old unused repos we no longer support.
  repo_names = %w[qt frameworks tmp_release] # pre-wily repos
  repo_names += %w[unstable stable release] # wily repos
  repo_names.each do |repo_name|
    next unless Aptly::Repository.exist?(repo_name)
    repo = Aptly::Repository.get(repo_name)
    repo.published_in(&:drop)
    repo.delete
  end
end
