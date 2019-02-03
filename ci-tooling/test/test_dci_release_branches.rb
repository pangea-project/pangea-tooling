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
require 'vcr'
require 'json'

require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class BranchingTest < TestCase
  def setup
    VCR.configure do |config|
      config.cassette_library_dir = "#{datadir}/fixtures/vcr_cassettes"
      config.hook_into :webmock
      config.filter_sensitive_data('<ACCESS_TOKEN>') {  ENV['OCTOKIT_TEST_GITHUB_TOKEN'] }
    end
  end

  def test_git_branching
    branches = %w(master Netrunner/1901)
    fixture_path = "#{datadir}/packaging"
    Dir.mktmpdir do |dir|
      FileUtils.mkpath(dir)
      Rugged::Repository.init_at(dir, :bare)
      Dir.chdir(dir) do
        repo = Rugged::Repository.clone_at(dir, "#{dir}/ring-kde")
        Dir.mkdir('debian') unless Dir.exist?('debian')
        raise "missing fixture: #{fixture_path}" unless File.exist?(fixture_path)

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
        repo.checkout 'Netrunner/1901'
        assert_equal 'Netrunner/1901', repo.head.name.sub(/^refs\/heads\//, '')
        assert repo.branches.exist?('master')
      end
    end
  end

  def test_github_branches
    VCR.use_cassette('get_branches') do
      headers = { 'Authentication' => ENV['OCTOKIT_TEST_GITHUB_TOKEN']  }
      link = 'https://api.github.com/orgs/dci-extras-packaging/repos?per_page=100'
      uri = URI.parse(link)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri, headers)
      response = http.request(request)
      assert_match /yarock/, response.body
      request = WebMock.stub_request(:get, uri).to_return(status: 200, body: response.body, headers: headers)
      resource = Octokit::Client.new(adapter: request)
      repos = resource.all_repositories
      assert_not_nil(repos)
      assert resource.repo('dci-extras-packaging/software-properties')
      assert resource.branch('dci-extras-packaging/yarock', 'Netrunner/18.03')
    end
  end
end
