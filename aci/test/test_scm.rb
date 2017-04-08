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
    name = 'kitties'
    url = 'https://github.com/ScarlettGatelyClark/new-tooling'
    branch = 'master'
    dir = File.join(Dir.pwd, name)
    type = 'git'
    file = 'kitties.tar.bz2'
    repo = SCM.new(url: url, branch: branch, dir: dir, type: type, file: file, name: name)
    assert_equal repo.url, url
    assert_equal repo.branch, branch
    assert_equal repo.dir, dir
    assert_equal repo.type, type
    assert_equal repo.name, name
    assert_equal repo.file, file
  end

  def test_clone
    name = 'new-tooling'
    url = 'https://github.com/ScarlettGatelyClark/new-tooling'
    branch = 'master'
    dir =  Dir.pwd + '/'
    type = 'git'
    repo = SCM.new(name: name, url: url, branch: branch, dir: dir, type: type)
    assert_equal repo.select_type, 0
    assert Dir.exist?(File.join(Dir.pwd, 'new-tooling'))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_wget
    file = 'kitties.tar.bz2'
    url = 'https://github.com/ScarlettGatelyClark/new-tooling/blob/master/kitties.tar.bz2'
    dir =  Dir.pwd
    repo = SCM.new(url: url, dir: dir, file: file)
    assert_equal repo.wget_source(url), 0
    FileUtils.rm(File.join(Dir.pwd, file))
  end

  def test_tar
    name = 'kitties'
    file = 'kitties.tar.xz'
    url =  'https://github.com/ScarlettGatelyClark/new-tooling/raw/master/kitties.tar.xz'
    dir =  Dir.pwd
    type = 'tar'
    repo = SCM.new(url: url, name: name, dir: dir, type: type, file: file)
    assert_equal(repo.select_type, 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rm(File.join(Dir.pwd, file))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_bz2
    name = 'kitties'
    file = 'kitties.tar.bz2'
    url =  'https://github.com/ScarlettGatelyClark/new-tooling/raw/master/kitties.tar.bz2'
    dir =  Dir.pwd
    type = 'tar'
    repo = SCM.new(url: url, name: name, dir: dir, file: file, type: type)
    assert_equal(repo.select_type, 0)
    assert_equal(repo.unpack_tar(name, url, file, dir), 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rm(File.join(Dir.pwd, file))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_gz
    name = 'kitties'
    file = 'kitties.tar.gz'
    url =  'https://github.com/ScarlettGatelyClark/new-tooling/raw/master/kitties.tar.gz'
    dir =  Dir.pwd
    type = 'tar'
    repo = SCM.new(url: url, name: name, dir: dir, file: file, type: type)
    assert_equal(repo.select_type, 0)
    assert_equal(repo.unpack_tar(name, url, file, dir), 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rm(File.join(Dir.pwd, file))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_zip
    name = 'kitties'
    file = 'kitties.zip'
    url =  'https://github.com/ScarlettGatelyClark/new-tooling/raw/master/kitties.zip'
    dir =  Dir.pwd
    type = 'zip'
    repo = SCM.new(url: url, name: name, dir: dir, file: file, type: type)
    assert_equal(repo.select_type, 0)
    assert_equal(repo.unpack_zip(name, url, file, dir), 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rm(File.join(Dir.pwd, file))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_bzr
    name = 'libdbusmenu'
    url = 'lp:libdbusmenu'
    dir = Dir.pwd
    type = 'bzr'
    assert_equal(repo.select_type, 0)
    repo = SCM.new(url: url, name: name, dir: dir, file: file, type: type)
    assert_equal(repo.select_type, 0)
    assert_equal(repo.branch_bzr(url, dir), 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rm_rf(File.join(Dir.pwd, name))
  end

  def test_none
    name = 'kitties'
    dir = Dir.pwd
    type = 'none'
    repo = SCM.new(url: url, name: name, dir: dir, file: file, type: type)
    assert_equal(repo.select_type, 0)
    assert_equal(repo.no_sources(dir, name), 0)
    assert Dir.exist?(File.join(Dir.pwd, name))
    FileUtils.rmdir(File.join(Dir.pwd, name))
  end
end
