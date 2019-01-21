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

require 'fileutils'
require 'tmpdir'
require 'rugged'
require 'octokit'

require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'


class ReleaseBranchTest < TestCase
  def test_file_exists
    File.exist?("#{__dir__}/../../../../pangea-conf-projects/dci/1901/release.yaml")
  end
  required_binaries %w[git]

  def git_init_repo(path)
    FileUtils.mkpath(path)
    Rugged::Repository.init_at(path, :bare)
    File.absolute_path(path)
  end

  def git_init_branch(repo_path, branches = %w(master Netrunner/1901))
    repo_path = File.absolute_path(repo_path)
    repo_name = File.basename(repo_path)
    fixture_path = "#{datadir}/packaging"
    Dir.mktmpdir do |dir|
      repo = Rugged::Repository.clone_at(repo_path, dir)
      Dir.chdir(dir) do
        Dir.mkdir('debian') unless Dir.exist?('debian')
        fail "missing fixture: #{fixture_path}" unless File.exist?(fixture_path)
        FileUtils.cp_r("#{fixture_path}/.", '.')

        index = repo.index
        index.add_all
        index.write
        tree = index.write_tree

        author = { name: 'Test', email: 'test@test.com', time: Time.now }
        Rugged::Commit.create(repo,
                              author: author,
                              message: 'commitmsg',
                              committer: author,
                              parents: [],
                              tree: tree,
                              update_ref: 'HEAD')

        branches.each do |branch|
          repo.create_branch(branch) unless repo.branches.exist?(branch)
        end
        origin = repo.remotes['origin']
        repo.references.each_name do |r|
          origin.push(r)
        end
      end
    end
  end

  def create_fake_git(prefix: nil, repo: nil, repos: [], branches:)
    repos << repo if repo

    # Create a new tmpdir within our existing tmpdir.
    # This is so that multiple fake_gits don't clash regardless of prefix
    # or not.
    remotetmpdir = Dir::Tmpname.create('d', "#{@tmpdir}/remote") {}
    FileUtils.mkpath(remotetmpdir)
    Dir.chdir(remotetmpdir) do
      repos.each do |r|
        path = File.join(*[prefix, r].compact)
        git_init_repo(path)
        git_init_branch(path, branches)
      end
    end
    remotetmpdir
  end

  def test_github_branching
    org = 'Fake_Org'
    repo = 'Fake_Repo'
    github_repos = %w("#{org}/#{repo}")
    github_dir = create_fake_git(branches: %w(master Netrunner/1901),
                                 repos: github_repos)


    WebMock.disable_net_connect!(allow_localhost: true)
    request = stub_request(:get, "https://api.github.com/#{org}/#{repo}")
    .with(
        headers: {
          'Accept'=>'application/vnd.github.v3+json',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Octokit Ruby Gem 4.13.0'
        }
      ).to_return(status: 200, body: '', headers: {})
    resource = Octokit::Client.new(adapter: request)
    resource.org('Fake_Org')
    resource.org_repos('Fake_Repo')
#    repo = Rugged::Repository.new(github_dir)
    #assert_equal 'Fake_Org', resource.org
#    assert_equal 'Netrunner/1901', repo.branch
  end
end
