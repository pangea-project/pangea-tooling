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

Aptly.configure do |c|
  c.host = 'localhost'
  c.port = 9090
end

# core
#   core/qt
#
# dev/core
#   dev/core/frameworks
#
# dev/unstable [core/qt + dev/core/frameworks + dev/unstable/plasma]
#   dev/unstable/plasma
#
# dev/stable [core/qt + dev/core/frameworks + dev/stable/plasma]
#   dev/stable/plasma
#
# user [core + user/frameworks + user/plasma]
#   user/frameworks
#   user/plasma
#
# testing [ core + testing/*]

# NB: in publish prefixes _ is replaced by / on the server, to get _ you need
#   to use __
repos = {
  'unstable' => 'dev_unstable',
  'stable' => 'dev_stable',
  'release' => 'tmp_release'
}
repos.each do |repo_name, publish_name|
  next if Aptly::Repository.exist?(repo_name)
  repo = Aptly::Repository.create(repo_name)
  repo.publish(publish_name || repo_name,
               Distribution: 'wily',
               Origin: 'Neon',
               Label: 'Neon',
               Architectures: %w[source i386 amd64 all])
end

repos = {
  'unstable_xenial' => 'dev_unstable',
  'stable_xenial' => 'dev_stable',
  'testing_xenial' => 'tmp_testing'
}
repos.each do |repo_name, publish_name|
  next if Aptly::Repository.exist?(repo_name)
  repo = Aptly::Repository.create(repo_name)
  repo.publish(publish_name || repo_name,
               Distribution: 'xenial',
               Origin: 'Neon',
               Label: 'Neon',
               Architectures: %w[source i386 amd64 armhf armel arm64 all])
end

repo_names = %w[qt frameworks tmp_release]
repo_names.each do |repo_name|
  next unless Aptly::Repository.exist?(repo_name)
  repo = Aptly::Repository.get(repo_name)
  repo.published_in(&:drop)
  repo.delete
end
