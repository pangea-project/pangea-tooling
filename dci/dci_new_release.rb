#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2021 Scarlett Moore <sgmoore@kde.org>
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

require_relative 'lib/branch'
require 'logger'
require 'logger/colors'

FLAVORS = %w[desktop core zeronet-rock64].freeze

# Class to process the release process.
class DCIRelease
  include Branching
  def initialize
    @depreciated = []
    @log = Logger.new($stdout).tap do |l|
      l.progname = 'snapshotter'
      l.level = Logger::INFO
    end
  end
    # cycle through each flavors project yaml and get fullname to retrieve the repository.
  def process_flavor_repos(flavor)
    projects = flavor_projects(flavor)
    projects.each do |project|
      next if SKIP.includes?(project.component)

      repo_fullname = "#{project.component}/#{project.name}"
      raise "Repository #{repo_fullname}does not exist" unless repo_exist?(repo_fullname)

      ensure_active_repo = master_branch_exist?(repo_fullname)
      next unless ensure_active_repo

      create_latest_series_branch(repo_fullname)
      merge_master_branch(repo_fullname)
    end
  end
end

r = DCIRelease.new
  FLAVORS.each do |flavor|
    r.process_flavor_repos(flavor)
  end

