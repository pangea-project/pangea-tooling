#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Scarlett Moore <sgclark@kde.org>
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

require 'octokit'
require 'deep_merge'
require 'yaml'
require 'json'
require_relative '../../lib/dci'
require_relative '../../lib/projects/factory'

SKIP = %w[linuxmint calamares].freeze


# Loop through DCI github repos and create release branches.
module Branching
  module_function

  def master_branch
    'heads/master'
  end

  def latest_series_branch
    "heads/Netrunner/#{DCI.latest_series}"
  end

  def previous_series_branch
    "heads/Netrunner/#{DCI.previous_series}"
  end

  def client
    Octokit.auto_paginate = true
    Octokit::Client.new(access_token: ENV['OCTOKIT_ACCESS_TOKEN'])
  end

  def flavor_projects(flavor)
    file = File.expand_path("#{flavor}.yaml", "data/projects/dci/#{DCI.latest_series}")
    ProjectsFactory.from_file(file, branch: latest_series_branch)
  end

  # Check for master branch, if it doesn't exist put in depreciated var to be consumed later with archiving.
  def master_branch_exist?(repo_fullname)
    branches = []
    repo_branches = client.branches(repo_fullname)
    repo_branches.each do |branch|
      branches << branch.name
    end
    exists = branches.include?('master')
    add_depreciated(repo_fullname) unless exists

    exists
  end

  # get list of repos by org, to be used in future for archiving depreciated repos.
  def get_org_repos(org)
    repos = []
    repositories = client.org_repos(org)
    repositories.each do |repo|
      repos << repo.name
    end
    repos.sort
  end

  # make sure the repo actually exists.
  def repo_exist?(repo_fullname)
    client.repository?(repo_fullname)
  end

  def add_depreciated(repo_fullname)
    puts "Repository #{repo_fullname} has no master branch and thus depreciated -- skipping"
    @depreciated.push(repo_fullname)
  end

  # cycle through each flavors project yaml and get fullname to retrieve the repository.
  def process_flavor_repos(flavor)
    projects = flavor_projects(flavor)
    projects.each do |project|
      next if SKIP.includes?(project.component)

      repo_fullname = "#{project.name}/#{project.component}"
      raise "Repository #{repo_fullname}does not exist" unless repo_exist?(repo_fullname)

      ensure_active_repo = master_branch_exist?(repo_fullname)
      next unless ensure_active_repo

      create_latest_series_branch(repo_fullname)
      merge_master_branch(repo_fullname)
    end
  end

  def create_latest_series_branch(repo_fullname)
    sha_latest_commit_previous_series_branch = client.ref(repo_fullname, previous_series_branch.object.sha)
    client.create_ref(repo_fullname, latest_series_branch, sha_latest_commit_previous_series_branch)
  end

  def merge_master_branch(repo_fullname)
    client.merge(repo_fullname, latest_series_branch, master_branch, { commit_message: 'Merged master branch' })
  end
end