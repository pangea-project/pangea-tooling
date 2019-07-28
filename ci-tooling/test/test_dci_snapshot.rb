#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Bhushan Shah <bshah@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
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

require_relative '../dci/snapshot'
require_relative 'lib/testcase'

require 'mocha/test_unit'
require 'webmock/test_unit'

class DCISnapshotTest < TestCase
  def setup
    # Disable all web (used for key).
    WebMock.disable_net_connect!
    ENV['DIST'] = 'netrunner-next'
    ENV['VERSION'] = 'next'
    @d = DCISnapshot.new('netrunner-desktop', 'next')
  end

  def teardown
    WebMock.allow_net_connect!
    ENV['DIST'] = nil
  end

  def test_config
    setup
    data = @d.config
    assert data.is_a?(Hash)
    teardown
  end

  def test_components
    setup
    data = @d.components
    assert data.is_a?(Array)
    test_data = %w[netrunner extras backports ds9-artwork ds9-common netrunner-desktop calamares plasma]
    assert_equal test_data, data
    teardown
  end

  def test_repo_array
    setup
    data = @d.repo_array
    assert data.include?('netrunner-next')
    teardown
  end

  def test_arch_array
    setup
    data = @d.arch_array
    assert data.include?('amd64')
    teardown
  end
end
