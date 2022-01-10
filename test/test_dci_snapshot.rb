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
    ENV['SERIES'] = 'next'
    ENV['SNAPSHOT'] = '1'
    ENV['WORKSPACE'] = File.dirname(__dir__) # main pangea-tooling dir
    @d = DCISnapshot.new
    @release = @d.send(:instance_variable_get, :@release)
    @series = @d.send(:instance_variable_get, :@series)
    @release_type = @d.send(:instance_variable_get, :@release_type)
    DCI.stubs(:arch_by_release).returns('armhf')
    @arch = @d.send(:instance_variable_get, :@arch)
    DCI.stubs(:release_components).returns(['netrunner-core', 'extras'])
    @components = @d.send(:instance_variable_get, :@components)
    @stamp = @d.send(:instance_variable_get, :@stamp)
    DCI.stubs(:release_distribution).returns('netrunner-core-c1-next')
    @release_distribution = @d.send(:instance_variable_get, :@release_distribution)
    DCI.stubs(:series_release_repos).returns('netrunner-core-next', 'extras-next')
    @repos = @d.send(:instance_variable_get, :@repos)

  end

  def teardown
    WebMock.allow_net_connect!
    ENV['RELEASE_TYPE'] = ''
    ENV['SERIES'] = ''
    ENV['ARM_BOARD'] = nil
    ENV['RELEASE'] = ''
    @d = ''
    @release = ''
    @series = ''
    @release_type = ''
    @arch = ''
    @components = ''
    @stamp = ''
    @release_distribution = ''
    @repos = ''
  end

  def test_arch_array
    setup
    assert(@d.arch_array.include?(@arch))
    teardown
  end

  def test_aptly_options
    setup
    opts = {}
    opts[:Distribution] = @release_distribution
    opts[:Architectures] = @d.arch_array
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    assert_equal(opts, @d.aptly_options)
    teardown
  end

  def test_snapshot_repo
    omit('Fails all year long with: NoMethodError: undefined method packages for "":String')
    setup
    opts = @d.aptly_options
    Aptly::Ext::Remote.expects(:connect).twice

    fake_repo = mock('repo')
    fake_repo.stubs(:packages).returns(['Parmhf base-files 10.5 abc'])
    fake_repo.stubs(:Name).returns('netrunner-core-next')
    fake_repo.stubs(:DefaultComponent).returns('netrunner-core')
    assert_true(@repos.include?(fake_repo.Name))
    @log = @d.send(:instance_variable_get, :@log)
    @repo = @d.send(:instance_variable_get, :@repo)
    Aptly::Repository.expects(:get).with('netrunner-core-next').returns(fake_repo)
    @log.expects(:info).with("Phase 1: Snapshotting repo: #{fake_repo.Name} with packages: #{fake_repo.packages}")
    assert_false(@repo.packages.empty?)
    fake_snapshot = mock('snapshot')
    assert(@repo.DefaultComponent == fake_repo.DefaultComponent)
    @aptly_snapshot = @d.send(:instance_variable_get, :@aptly_snapshot)
    @d.instance_variable_set(:@aptly_snapshot.DefaultComponent, fake_repo.DefaultComponent)
    @repo.expects(:snapshot).with("#{fake_repo.Name}_#{@release_distribution}_#{@stamp}", opts).returns(fake_snapshot)
    @snapshots = @d.send(:instance_variable_get, :@snapshots)
    assert_not_nil(@snapshots)
    assert(@snapshots.include?(@aptly_snapshot))
    assert_equal(@aptly_snapshot.DefaultComponent, fake_repo.DefaultComponent)
    @d.snapshot_repo
    teardown


    fake_repo2 = mock('repo')
    fake_repo2.stubs(:packages).returns(nil)
    fake_repo2.stubs(:Name).returns('extras-next')
    fake_repo2.stubs(:DefaultComponent).returns('extras')
    @d.instance_variable_set(:@repo, 'extras-next')
    @repo =
    Aptly::Repository.expects(:get).with(fake_repo.Name).returns(fake_repo)
    @log.expects(:info).with("Phase 1: Snapshotting repo: #{fake_repo2.Name} with packages: #{fake_repo2.packages}")
    fake_snapshot2 = mock('snapshot')
    fake_snapshot2.stubs(:DefaultComponent).returns(fake_repo2.DefaultComponent)
    @aptly_snapshot = @d.send(:instance_variable_get, :@aptly_snapshot)
    @snapshots = @d.send(:instance_variable_get, :@snapshots)
    Aptly::Snapshot.expects(:create).with("#{fake_repo2.Name}_#{@default_distribution}_#{@stamp}").returns(fake_snapshot2)

    assert(@snapshots.count = 2)
    @d.snapshot_repo
    teardown
  end
end
