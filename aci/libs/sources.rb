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
require 'yaml'
require 'fileutils'

class Sources
  attr_accessor :name

  def initialize() end

  def get_source(name, type, url, branch='master')
    Dir.chdir('/source/')
    FileUtils.rm_rf("/source/#{name}") if File.directory?("/source/#{name}")
    case type
    when 'git'
      system( "git clone #{url}")
      unless branch == 'master'
        Dir.chdir("/source/#{name}")
        system("git checkout #{branch}")
      end
    when 'xz'
      system("wget #{url}")
      system("tar -xvf #{name}*.tar.xz")
    when 'gz'
      system("wget #{url}")
      system("tar -zxvf #{name}*.tar.gz")
    when 'bz2'
      system("wget #{url}")
      system("tar -jxvf #{name}.tar.bz2")
    when 'mercurial'
      system("hg clone #{url}")
    when 'bzr'
      system("bzr branch #{url}")
    when 'zip'
      system("wget #{url}")
      system("unzip #{name}.zip")
    when 'svn'
      system("svn export #{url}")
    when 'none'
      Dir.mkdir "#{name}"
    else
      "You gave me #{type} -- I have no idea what to do with that."
    end
    $?.exitstatus
  end

  def run_build(name, buildsystem, options, autoreconf=false, insource=false)
    if name == Metadata::PROJECT
      Dir.chdir(Metadata::PROJECTPATH)
    else
      Dir.chdir(Metadata::DEPATH + name)
    end
    case buildsystem
    when 'make'
      cmd = "autoreconf --force --install &&  ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr" if autoreconf && insource
      cmd = "autoreconf --force --install && mkdir #{name}-builddir && cd #{name}-builddir && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr" if autoreconf && !insource
      cmd = "../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install" if insource && !autoreconf
      cmd = "mkdir #{name}-builddir && cd #{name}-builddir && ../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install" if !insource && !autoreconf
    when 'autogen'
      cmd = "autoreconf --force --install && ./autogen && ./configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr" if autoreconf && insource
      cmd = "autoreconf --force --install && cd #{name} && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr" if autoreconf && !insource
      cmd = "./autogen && ../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install"   if insource && !autoreconf
      cmd = "mkdir #{name}-builddir && cd #{name}-builddir && ../autogen && ./configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install" if !insource && !autoreconf
    when 'cmake'
      cmd = "mkdir #{name}-builddir  && cd #{name}-builddir  && cmake #{options} ../ && make VERBOSE=1 -j 8 && make install"
    when 'custom'
      cmd = options
    when 'qmake'
      cmd = "#{options}" + 'make VERBOSE=1 -j 8 && make install'
    when 'bootstrap'
      cmd = "./bootstrap #{options}" + 'make VERBOSE=1 -j 8 && make install'
    else
      p "You gave me #{buildsystem} -- I have no idea what to do with that."
    end
    p "Running " + ' ' + buildsystem + ' ' + cmd
    system(cmd)
    $?.exitstatus
  end
end
