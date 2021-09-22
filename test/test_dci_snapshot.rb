#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2016 Bhushan Shah <bshah@kde.org>
# SPDX-FileCopyrightText: 2016 Rohan Garg <rohan@kde.org>
# SPDX-FileCopyrightText: 2019-2021 Scarlett Moore <sgmoore@kde.org>

require_relative '../lib/dci'
require_relative '../dci/snapshot'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class DCISnapshotTest < TestCase
  @data = {}

  def setup
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['RELEASE_TYPE'] = 'core'
    ENV['SERIES'] = 'next'
    ENV['ARM_BOARD'] = 'c1'
    ENV['WORKSPACE'] = File.dirname(__dir__) # main pangea-tooling dir
    @d = DCISnapshot.new
    @data = @d.config
    @series = @d.series
    @release_types = @d.release_types
    @release_type = @d.release_type
    @type_data = @d.type_data
    @release = @d.release
    @release_data = DCI.get_release_data(@release_type, @release)
    @currentdist = @d.currentdist
    @series_release = @d.series_release
    @arch = DCI.arch_by_release(@release_data)
    @arm_board = DCI.arm_board_by_release(@release_data)
    @arch_array = @d.arch_array
    @components = DCI.components_by_release(@release_data)
    @repos = @d.aptly_components_to_repos
    @aptly_options = @d.aptly_options
  end

  def teardown
    WebMock.allow_net_connect!
    ENV['RELEASE_TYPE'] = ''
    ENV['SERIES'] = ''
    ENV['ARM_BOARD'] = ''
  end

  def test_config
    setup
    assert_is_a(@data, Hash)
    assert_equal @data.keys, %w[desktop core zeronet zynthbox]
    teardown
  end

  def test_release_type
    setup
    assert_equal @release_type, ENV['RELEASE_TYPE']
    assert @data.keys.include?(@release_type)
    teardown
  end

  def test_release_types
    setup
    assert @release_types.include?(@release_type)
    teardown
  end

  def test_type_data
    setup
    assert_is_a(@type_data, Hash)
    assert_equal @type_data.keys, %w[netrunner-core netrunner-core-c1]
    teardown
  end
  
  def test_release
    setup
    assert_equal(@release, 'netrunner-core-c1')
    teardown
  end

  def test_currentdist
    setup
    assert_equal @currentdist.keys, %i[repo releases snapshots]
    assert_equal @currentdist[:repo], 'https://github.com/netrunner-odroid/c1-live-build-core'
    assert_equal @currentdist, @d.currentdist
    teardown
  end

  def test_components
    setup
    test_data = 'netrunner extras artwork common backports c1 netrunner-core'
    assert_equal test_data, @components
    teardown
  end

  def test_arch
    setup
    assert_equal 'armhf', @arch
    teardown
  end

  def test_aptly_components_to_repos
    setup
    assert_equal  %w[netrunner-next extras-next artwork-next common-next backports-next c1-next netrunner-core-next], @repos
    teardown
  end

  def test_arch_array
    setup
    assert @arch_array.include?('armhf')
    teardown
  end

  def test_series_release
    setup
    assert_equal('netrunner-core-c1-next', @series_release)
    teardown
  end

  def test_aptly_options
    setup
    opts = {}
    opts[:Distribution] = @series_release
    opts[:Architectures] =@arch_array
    opts[:ForceOverwrite] = true
    opts[:SourceKind] = 'snapshot'
    assert_equal(opts, @aptly_options)
    teardown
  end
end
