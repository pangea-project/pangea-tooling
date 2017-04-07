#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
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
require_relative '../libs/scm'
require 'fileutils'
require 'test/unit'

# Test various aspects of scm
class TestBuild < Test::Unit::TestCase
  def test_vars
    name = 'extra-cmake-modules'
    url = 'http://anongit.kde.org/extra-cmake-modules'
    branch = 'master'
    dir = File.join(Dir.pwd, name)
    type = 'git'
    repo = SCM.new(url: url, branch: branch, dir: dir, type: type)
    assert_equal repo.url, url
    assert_equal repo.branch, branch
    assert_equal repo.dir, dir
    assert_equal repo.type, type
  end

  def test_clone
    name = 'extra-cmake-modules'
    url = 'http://anongit.kde.org/extra-cmake-modules'
    branch = 'master'
    dir =  File.join(Dir.pwd, name)
    type = 'git'
    repo = SCM.new(url: url, branch: branch, dir: dir, type: type)
    assert_nothing_raised RuntimeError do
      repo.select_type
    end
    assert Dir.exist?(File.join(Dir.pwd, 'extra-cmake-modules'))
    FileUtils.rm_rf(File.join(Dir.pwd, 'extra-cmake-modules'))
  end
end
