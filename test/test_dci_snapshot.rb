#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2016 Bhushan Shah <bshah@kde.org>
# SPDX-FileCopyrightText: 2016 Rohan Garg <rohan@kde.org>
# SPDX-FileCopyrightText: 2019-2021 Scarlett Moore <sgmoore@kde.org>

require_relative '../dci/snapshot'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class DCISnapshotTest < TestCase
  @data = {}

  def setup
    omit('FIXME Code broken')
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['RELEASE_TYPE'] = 'desktop'
    ENV['SERIES'] = 'next'
    ENV['WORKSPACE'] = File.dirname(__dir__) # main pangea-tooling dir
    @d = DCISnapshot.new
    @data = @d.config
    @dist = @d.distribution
    @release_types = @d.release_types
    @type = @d.type
    @type_data = @d.type_data
    @currentdist = @d.currentdist
    @arch = @d.arch
    @arch_array = @d.arch_array
    @components = @d.components
    @repos = @d.aptly_components_to_repos
    @versioned_dist = @d.versioned_dist
    @aptly_options = @d.aptly_options
  end

  def teardown
    WebMock.allow_net_connect!
    ENV['RELEASE_TYPE'] = ''
    ENV['SERIES'] = ''
  end

  def test_config
    setup
    assert_is_a(@data, Hash)
    assert_equal @data.keys, %w[desktop core zeronet]
    teardown
  end

  def test_type
    setup
    assert_equal @type, ENV['FLAVOR']
    assert @data.keys.include?(@type)
    teardown
  end

  def test_release_types
    setup
    assert_equal @type, 'desktop'
    assert @release_types.include? (@type)
    teardown
  end

  def test_type_data
    setup
    assert_is_a(@type_data, Hash)
    assert_equal @type_data.keys, %w[netrunner-desktop]
    teardown
  end

  def test_currentdist
    setup
    type = @d.type()
    dist = @d.distribution()
    @data = @d.config()
    assert @data.keys.include?(type)
    currentdist = @data[type]
    @currentdist = currentdist[dist]
    assert_equal @currentdist.keys, [:repo, :architecture, :components, :releases, :snapshots]
    assert_equal @currentdist[:components], 'netrunner,common,artwork,extras,backports,netrunner-desktop,netrunner-core'
    assert_equal @currentdist, @d.currentdist()
    teardown
  end

  def test_components
    setup
    test_data = %w[netrunner extras backports netrunner-desktop netrunner-core]
    assert_equal test_data, @components
    teardown
  end

  def test_arch
    setup
    test_data = 'amd64'
    assert_equal test_data, @arch
    teardown
  end

  def test_aptly_components_to_repos
    setup
    assert_equal @repos, ["netrunner-next", "extras-next", "backports-next", "netrunner-desktop-next", "netrunner-core-next"]
    teardown
  end

  def test_arch_array
    setup
    assert @arch_array.include?('amd64')
    teardown
  end

  def test_versioned_dist
    setup
    assert_equal('netrunner-desktop-next', @versioned_dist)
    teardown
  end

  def test_aptly_options
    setup
    opts = {}
    opts[:Distribution] = @versioned_dist
    opts[:Architectures] =@arch_array
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    assert_equal(opts, @aptly_options)
    teardown
  end
end
