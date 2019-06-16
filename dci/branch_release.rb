#!/usr/bin/env ruby
# frozen_string_literal: true
#
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

require 'octokit'
require 'deep_merge'
require 'yaml'
require_relative '../lib/ci/pattern'


Octokit.auto_paginate = true

RELEASE = '19.01'

#Loop through DCI github repos and create release branches.
class ReleaseBranch
  def load(file)
    hash = {}
    hash.deep_merge!(YAML.load(File.read(File.expand_path(file))))
    hash = CI::FNMatchPattern.convert_hash(hash, recurse: false)
    hash
  end

  def branch_release
    file = "ci-tooling/data/projects/dci/next/release.yaml"
    data = YAML.load(File.read(file))
    raise unless data.is_a?(Hash)
    client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    user = client.user
    user.login
    repositories = []
    base_branch = 'master'
    new_branch = "Netrunner/#{RELEASE}"
    data.each do |_api, orgs|
      orgs.collect do |org|
        org.each do |org_name, org_repos|
          org_repos.each do |repo|
            if repo.include?('*')
              repos = client.org_repos(org_name)
              repos.each do |org_repo, _branch|
                repositories << org_repo.full_name
              end
            else
              repo.each do |org_repo, branch|
                if org_repo =~ /{.*}\*$/
                  org_repo = org_repo.split(',')
                  org_repo.each do |r|
                    repo = r.gsub(/[\s,{}*]/, '')
                    repos = client.org_repos(org_name)
                    repos.each do |m_org_repo|
                      if m_org_repo.name =~ /#{repo}.*/
                        repositories << m_org_repo.full_name
                      end
                    end
                  end
                elsif org_repo =~ /{.*}-\*$/
                  org_repo = org_repo.split(',')
                  org_repo.each do |r|
                    repo = r.gsub(/[\s,{}*-]/, '')
                    repos = client.org_repos(org_name)
                    repos.each do |m_org_repo|
                      if m_org_repo.name =~ /#{repo}.*/
                        repositories << m_org_repo.full_name
                      end
                    end
                  end
                elsif org_repo =~ /\w-{.*}/
                  org_repo = org_repo.split(',')
                  org_repo.each do |r|
                    repo = r.gsub(/[\s,{}*-]/, '')
                    repos = client.org_repos(org_name)
                    repos.each do |m_org_repo|
                      if m_org_repo.name =~ /#{repo}.*/
                        repositories << m_org_repo.full_name
                      end
                    end
                  end
                else
                  repositories << "#{org_name}/#{org_repo}"
                  repositories.each do |r|
                    puts "Checking #{r}"
                    branches = client.branches(r).collect(&:name)
                    puts branches
                    if branches.include?(new_branch)
                      puts "#{new_branch} already exists"
                      next
                    end
                    if r == 'linuxmint/mintinstall'
                      puts "Skipping linuxmint/mintinstall"
                      next
                    end
                    if r == 'calamares/calamares-debian'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'plasmazilla/mozilla-kde-support'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'plasmazilla/thunderbird'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'ds9-artwork/amos-kvantum-theme'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'ds9-artwork/amos-plasma-look-and-feel'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'ds9-artwork/amos-grub-theme'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'ds9-artwork/amos-plymouth-theme'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'netrunner-odroid/odroid-boot-services'
                      puts "Skipping calamares/calamares-debian"
                      next
                    end
                    if r == 'netrunner-odroid/xserver-xorg-video-mali'
                      puts "Skipping netrunner-odroid/xserver-xorg-video-mali"
                      next
                    end
                    if r.include?('mycroft-packaging')
                      puts "Skipping netrunner-odriod"
                      next
                    end
                    if r.include?('netrunner-pinebook')
                      puts "Skipping netrunner-odriod"
                      next
                    end
                    if r.include?('netrunner-rock64')
                      puts "Skipping netrunner-odriod"
                      next
                    end
                    if branches.include?(base_branch)
                      ref = client.branch(r, base_branch)
                      client.create_ref(r, "heads/#{new_branch}", ref.commit.sha)
                      puts "Done for #{r}"
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

yaml = ReleaseBranch.new

yaml.branch_release
