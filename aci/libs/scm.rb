#!/usr/bin/env ruby
# frozen_string_literal: true

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
require 'fileutils'
require 'rugged'
require 'English'

# Module for source control
class SCM
  attr_accessor :url
  attr_accessor :branch
  attr_accessor :dir
  attr_accessor :type
  attr_accessor :name
  attr_accessor :file
  def initialize(args = {})
    self.url = args[:url]
    self.branch = args[:branch]
    self.dir = args[:dir]
    self.type = args[:type]
    self.name = args[:name]
    self.file = args[:file]
  end

  # Case block to select appriate scm type.
  def select_type
    case type
    when 'git'
      git_clone_source(name, url, dir, branch)
    when 'tar'
      unpack_tar(name, url, file, dir)
    when 'mercurial'
      clone_mercurial(url, dir)
    when 'bzr'
      branch_bzr(url, dir)
    when 'zip'
      unpack_zip(url, file, dir)
    when 'svn'
      export_svn(url, dir)
    when 'none'
      no_sources
    else
      "You gave me #{type} -- I have no idea what to do with that."
    end
  end

  # Clone a git repo
  def git_clone_source(name, url, dir, branch)
    path = dir + name
    Rugged::Repository.clone_at(
      url,
      path,
      checkout_branch: branch,
      transfer_progress: lambda { |total_objects, indexed_objects, received_objects, local_objects, total_deltas, indexed_deltas, received_bytes|
        # ...
      }
    )
    $CHILD_STATUS.exitstatus
  end

  # wget typically for compressed source
  def wget_source(url)
    system('wget ' + url)
    $CHILD_STATUS.exitstatus
  end

  # unpack tar file
  def unpack_tar(name, url, file, dir)
    Dir.chdir(dir)
    wget_source(url)
    Dir.mkdir(File.join(dir, name))
    type = file.split('.')[-1]
    case type
    when 'xz'
      system('tar xvf ' + file + ' -C  ' + name + ' --strip-components 1')
      $CHILD_STATUS.exitstatus
    when 'gz'
      system('tar zxvf ' + file + ' -C  ' + name + ' --strip-components 1')
      $CHILD_STATUS.exitstatus
    when 'bz2'
      system('tar jxvf ' + file + ' -C  ' + name + ' --strip-components 1')
      $CHILD_STATUS.exitstatus
    end
  end

  def unpack_zip(name, url, file, dir)
    wget_source(url)
    Dir.mkdir(File.join(dir, name))
    path = File.join(dir, name)
    system('unzip ' + file + ' -d ' + path)
    $CHILD_STATUS.exitstatus
  end

  def clone_mercurial(url, dir)
    Dir.chdir(dir)
    system('hg clone ' + url)
  end

  def branch_bzr(url, dir)
    Dir.chdir(dir)
    system('bzr branch ' + url)
    $CHILD_STATUS.exitstatus
  end

  def export_svn(url, dir)
    Dir.chdir(dir)
    system('svn export ' + url)
    $CHILD_STATUS.exitstatus
  end

  def no_sources(dir, name)
    Dir.mkdir(File.join(dir, name))
    $CHILD_STATUS.exitstatus
  end
end
