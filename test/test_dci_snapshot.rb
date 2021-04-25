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
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['FLAVOR'] = 'desktop'
    ENV['VERSION'] = 'next'
    ENV['WORKSPACE'] = File.dirname(__dir__) # main pangea-tooling dir
    @d = DCISnapshot.new
    @data = @d.config
  end

  def teardown
    WebMock.allow_net_connect!
    ENV['FLAVOR'] = ''
    ENV['VERSION'] = ''
  end

  def test_config
    setup
    data = @d.config
    assert_is_a(@data, Hash)
    assert_is_a(data, Hash)
    assert_equal @data.keys, %w[desktop core zeronet]
    teardown
  end

  def test_distribution
    setup
    distribution = @d.distribution
    assert_is_a(distribution, String)
    assert_equal distribution, 'netrunner-desktop'
    teardown
  end

  def test_type
    setup
    type = @d.type
    assert_equal type, ENV['FLAVOR']
    assert @data.keys.include?(type)
    teardown
  end

  def test_type_data
    setup
    type_data = @d.type_data
    assert_is_a(type_data, Hash)
    assert_equal type_data.keys, %w[netrunner-desktop]
    teardown
  end

  def test_currentdist
    setup
    @type = @d.type
    assert_equal @type,  'desktop'
    dist = @d.distribution
    assert_equal dist, 'netrunner-desktop'
    assert_equal @type, @d.type
    type_data = @d.type_data
    assert_equal type_data, @d.type_data
    assert type_data.keys.include?(dist)
    @currentdist = type_data[dist]
    assert_is_a(@currentdist, Hash)
    assert_equal @currentdist.keys, [:repo, :architecture, :components, :releases, :snapshots]
    assert_equal @currentdist[:components], 'netrunner,extras,backports,netrunner-desktop,netrunner-core'
    assert_equal @currentdist, @d.currentdist
    teardown
  end

  def test_components
    setup
    components = @d.components()
    test_data = %w[netrunner extras backports netrunner-desktop netrunner-core]
    assert_equal test_data, components
    teardown
  end

  def test_arch
    setup
    arch = @d.arch
    test_data = 'amd64'
    assert_equal test_data, arch
    teardown
  end

  def test_aptly_component_array
    setup
    data = @d.aptly_component_array
    assert_equal data, ["netrunner", "extras", "backports", "netrunner-desktop", "netrunner-core"]
    teardown
  end

  def test_arch_array
    setup
    data = @d.arch_array
    assert data.include?('amd64')
    teardown
  end

  def test_versioned_dist
    setup
    v_dist = @d.versioned_dist
    assert_equal('netrunner-desktop-next', v_dist)
    teardown
  end

  def test_aptly_options
    setup
    data = @d.aptly_options
    opts = {}
    opts[:Distribution] = 'netrunner-desktop-next'
    opts[:Architectures] = %w[amd64 i386 all source]
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    assert_equal(opts, data)
    teardown
  end
end
