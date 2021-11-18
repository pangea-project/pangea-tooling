#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2021 Scarlett Moore <sgmoore@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/ci/overrides'
require_relative '../lib/projects/factory'
require_relative 'lib/testcase'
require_relative '../dci/lib/branch'
require_relative '../lib/dci'

require 'net/ssh/gateway'
require 'vcr'
require 'webmock'
require 'webmock/test_unit'

require 'mocha/test_unit'

class DCIBranchingTest < TestCase
  include Branching

  def setup
    VCR.configure do |c|
      c.hook_into :webmock
      c.cassette_library_dir = datadir
      c.default_cassette_options = {
        match_requests_on: %i[method uri body]
      }
      c.filter_sensitive_data('<AUTH_TOKEN>') do |interaction|
        interaction.request.headers['Authorization'].first
      end
    end
    @depreciated = []
    VCR.turn_on!
  end

  def teardown
    ProjectsFactory.factories.each do |factory|
      factory.send(:reset!)
    end
  end

  def test_get_org_repos
    setup
    VCR.use_cassette('get_org_repos', record: :new_episodes) do
      org_repos = get_org_repos('netrunner-desktop')
      assert_true(org_repos.is_a?(Array))
      assert_equal(true, org_repos.include?('netrunner-desktop'))
      assert_equal(
        ["base-files",
         "calamares-desktop",
         "live-build",
         "live-build-final",
         "netrunner-desktop",
         "netrunner-desktop-plasma5-panels",
         "netrunner-desktop-settings",
         "netrunner-desktop-settings-desktop"], org_repos.sort
      )
    end
    teardown
  end

  def test_repo_exist?
    setup
    VCR.use_cassette('repo_exist?', record: :new_episodes) do
      exists = repo_exist?('netrunner-desktop/netrunner-desktop')
      assert_true(exists)
      exists = repo_exist?('netrunner-desktop/netrunner-file')
      assert_false(exists)
    end
    teardown
  end

  def test_branches
    assert_equal(master_branch, 'heads/master')
    assert_equal(latest_series_branch, "heads/Netrunner/#{DCI.latest_series}")
    assert_equal(previous_series_branch, "heads/Netrunner/#{DCI.previous_series}")
  end
  
  def test_master_branch_exist?
    setup
    VCR.use_cassette('master_branch_exist?', record: :new_episodes) do
      assert_false(master_branch_exist?('netrunner-desktop/netrunner-desktop-plasma5-panels'))
      assert_true(master_branch_exist?('netrunner-desktop/netrunner-desktop'))
    end
  end

  def test_depreciated
    setup
    VCR.use_cassette('depreciated', record: :new_episodes) do
      repo = 'netrunner-desktop/netrunner-desktop-plasma5-panels'
      d = add_depreciated(repo)
      assert_true(d.include?(repo))
    end
    teardown
  end

end