#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2016 Bhushan Shah <bshah@kde.org>
# SPDX-FileCopyrightText: 2016 Rohan Garg <rohan@kde.org>
# SPDX-FileCopyrightText: 2019-2021 Scarlett Moore <sgmoore@kde.org>

require 'aptly'
require_relative '../lib/dci'
require_relative '../dci/snapshot'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class DCISnapshotTest < TestCase

  def setup
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['RELEASE_TYPE'] = 'core'
    ENV['RELEASE'] = 'netrunner-core-c1'
    ENV['DIST'] = 'next'
    ENV['SNAPSHOT'] = '1'
    ENV['WORKSPACE'] = File.dirname(__dir__) # main pangea-tooling dir
    @d = DCISnapshot.new
    # @release = @d.send(:instance_variable_get, :@release)
    # @series = @d.send(:instance_variable_get, :@series)
    # @release_type = @d.send(:instance_variable_get, :@release_type)
    # DCI.stubs(:release_components).returns(['netrunner-core'])
    # @components = @d.send(:instance_variable_get, :@components)
    # @stamp = @d.send(:instance_variable_get, :@stamp)
    # DCI.stubs(:release_distribution).returns('netrunner-core-c1-next')
    # @release_distribution = @d.send(:instance_variable_get, :@release_distribution)


  end

  def teardown
    WebMock.allow_net_connect!
    ENV['RELEASE_TYPE'] = ''
    ENV['DIST'] = ''
    ENV['ARM_BOARD'] = nil
    ENV['RELEASE'] = ''
    @d = ''
    @release = ''
    @series = ''
    @release_type = ''
    @stamp = ''
    @repos = ''
  end

  def test_arch_array
    setup
    release_arch = DCI.arch_by_release(DCI.get_release_data(ENV['RELEASE_TYPE'], ENV['RELEASE']))
    assert_equal('armhf', release_arch)
    @arch_array = @d.arch_array
    @arch = @d.send(:instance_variable_get, :@arch)
    assert_equal(release_arch, @arch)
    assert_equal(['armhf', 'i386', 'all', 'source'], @arch_array)
    teardown
  end

  def test_aptly_options
    setup
    fake_options = mock('fake_options')
    fake_options.stubs(:Distribution).returns('netrunner-core-c1')
    fake_options.stubs(:Architectures).returns(['armhf', 'i386', 'all', 'source'])
    fake_options.stubs(:ForceOverwrite).returns(true)
    fake_options.stubs(:SourceKind).returns('snapshot')
    @d.aptly_options
    @release = @d.send(:instance_variable_get, :@release)
    assert_equal(@release, fake_options.Distribution)
    @arch_array = @d.send(:instance_variable_get, :@arch_array)
    assert_equal(@arch_array, fake_options.Architectures)
    assert_equal(true, fake_options.ForceOverwrite)
    assert_equal('snapshot', fake_options.SourceKind)
    teardown
  end

  def test_aptly_repo
    setup
    packages = [
      'Pall kitteh 999 66f130f348dc4864',
      'Pall kitteh 997 66f130f348dc4864',
      'Pall kitteh 998 66f130f348dc4864',
      'Pamd64 doge 1 66f130f348dc4864',
      'Pamd64 doge 3 66f130f348dc4864',
      'Pamd64 doge 2 66f130f348dc4864'
    ]
    repo_name = 'netrunner-core-next'
    fake_repo = mock('fake_repo')
    fake_repo.stubs(:Name).returns('netrunner-core-next')
    fake_repo.stubs(:DefaultComponent).returns('netrunner-core')
    fake_repo.stubs(:packages).returns(packages)
    Aptly::Repository.expects(:get).with('netrunner-core-next').returns(fake_repo)
    @d.aptly_repo(repo_name)
    assert_false(fake_repo.packages.empty?)
    assert_equal(fake_repo.packages, packages)
    assert_equal(fake_repo.DefaultComponent, 'netrunner-core')
    assert_equal(fake_repo.Name, 'netrunner-core-next')
    @repo = @d.send(:instance_variable_get, :@repo)
    assert_equal(@repo.Name, 'netrunner-core-next')
    teardown
  end

  def test_release_repos
    setup
    DCI.stubs(:series_release_repos).returns(['netrunner-core-next', 'extras-next'])
    release_repos = @d.release_repos
    assert_equal(['netrunner-core-next', 'extras-next'], release_repos)
    teardown
  end

  def test_snapshot_repo
    setup
    fake_remote = mock('fake_remote')
    fake_remote.stubs(:default_connection_options)
    fake_remote.stubs(:new)
    fake_remote.stubs(:connect)
    Aptly::Ext::Remote.expects(:dci).returns(fake_remote)
    fake_snapshot = mock('fake_snapshot')
    @d.aptly_repo('netrunner-core-next')
    @d.snapshot_repo
    @repo = @d.send(:instance_variable_get, :@repo)
    instance_variable_set(@repo.packages, nil)
    Aptly::Snapshot.expects(:create).with("netrunner-core-next_netrunner-core-c1-next_#{@stamp}", @d.aptly_options).returns(fake_snapshot)
    @repo = @d.send(:instance_variable_get, :@repo)
    teardown
  end
end
