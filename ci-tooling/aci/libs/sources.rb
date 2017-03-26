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

class Sources
  attr_accessor :name

  def initialize()
    Dir.mkdir('/source')
  end

  def get_source(name, type, url, branch='master')
    case "#{type}"
    when 'git'
      Dir.chdir('/source/')
      unless Dir.exist?("/source/#{name}")
        system( "git clone #{url}")
        unless branch == 'master'
          Dir.chdir("/source/#{name}")
          system("git checkout #{branch}")
        end
      end
    when 'xz'
      Dir.chdir('/source/')
      unless Dir.exist?("/source/#{name}")
        system("wget #{url}")
        system("tar -xvf #{name}*.tar.xz")
      end
    when 'gz'
      Dir.chdir('/source/')
      unless Dir.exist?("/source/#{name}")
        system("wget #{url}")
        system("tar -zxvf #{name}*.tar.gz")
      end
    when 'bz2'
      Dir.chdir('/source/')
      unless Dir.exist?("/source/#{name}")
        system("wget #{url}")
        system("tar -jxvf #{name}.tar.bz2")
      end
    when 'mercurial'
      Dir.chdir('/source')
      unless Dir.exist?("/source/#{name}")
        system("hg clone #{url}")
      end
    when 'bzr'
      Dir.chdir('/source')
      unless Dir.exist?("/source/#{name}")
        system("bzr branch #{url}")
      end
    when 'zip'
      Dir.chdir('/source')
      unless Dir.exist?("/source/#{name}")
        system("wget #{url}")
        system("unzip #{name}.zip")
      end
    when 'svn'
      Dir.chdir('/source')
      unless Dir.exist?("/source/#{name}")
        system("svn export #{url}")
      end
    when 'none'
      Dir.chdir('/source')
      unless Dir.exist?("/source/#{name}")
        Dir.mkdir "#{name}"
        p "No sources configured"
      end
    else
      "You gave me #{type} -- I have no idea what to do with that."
    end
    $?.exitstatus
  end

  def run_build(name, buildsystem, options, path, autoreconf=false, insource=false)
    ENV['PATH']='/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    ENV['LD_LIBRARY_PATH']='/opt/usr/lib:/opt/usr/lib/x86_64-linux-gnu:/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib64:/usr/lib:/lib:/lib64'
    ENV['CPLUS_INCLUDE_PATH']='/opt/usr:/opt/usr/include:/usr/include'
    ENV['CFLAGS']="-g -O2 -fPIC"
    ENV['CXXFLAGS']='-std=c++11'
    ENV['PKG_CONFIG_PATH']='/opt/usr/lib/pkgconfig:/opt/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig'
    ENV['ACLOCAL_PATH']='/opt/usr/share/aclocal:/usr/share/aclocal'
    ENV['XDG_DATA_DIRS']='/opt/usr/share:/opt/share:/usr/local/share/:/usr/share:/share'
    ENV.fetch('PATH')
    ENV.fetch('LD_LIBRARY_PATH')
    ENV.fetch('CFLAGS')
    ENV.fetch('CXXFLAGS')
    ENV.fetch('PKG_CONFIG_PATH')
    ENV.fetch('ACLOCAL_PATH')
    ENV.fetch('CPLUS_INCLUDE_PATH')
    ENV.fetch('XDG_DATA_DIRS')
    system( "echo $PATH" )
    system( "echo $LD_LIBRARY_PATH" )
    system( "echo $CFLAGS" )
    system( "echo $CXXFLAGS" )
    system( "echo $PKG_CONFIG_PATH" )
    system( "echo $ACLOCAL_PATH" )
    system( "echo $CPLUS_INCLUDE_PATH" )
    system( "echo $XDG_DATA_DIRS" )
    case "#{buildsystem}"
    when 'make'
      Dir.chdir("#{path}") do
        unless "#{autoreconf}" == true
          unless "#{insource}" == true
            cmd = "mkdir #{name}-builddir && cd #{name}-builddir && ../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install"
          end
          if "#{insource}" == true
            cmd = "cd #{name} && ../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install"
          end
          p "Running " + cmd
          system(cmd)
          system("rm -rfv  #{name}-builddir")
        end
        if "#{autoreconf}" == true
          p "Running " + cmd
          unless "#{insource}" == true
            cmd = "autoreconf --force --install && mkdir #{name}-builddir && cd #{name}-builddir && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr"
          end
          if "#{insource}" == true
            cmd = "autoreconf --force --install && cd #{name} && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr"
          end
          system(cmd)
          system("rm -rfv  #{name}-builddir")
        end
      end
      $?.exitstatus
    when 'autogen'
        Dir.chdir("#{path}") do
          unless "#{autoreconf}" == true
            unless "#{insource}" == true
              cmd = "mkdir #{name}-builddir && cd #{name}-builddir && ../autogen && ../configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install"
            end
            if "#{insource}" == true
              cmd = "cd #{name} && ./autogen && ./configure --prefix=/opt/usr #{options} && make VERBOSE=1 -j 8 && make install"
            end
            p "Running " + cmd
            system(cmd)
            system("rm -rfv  #{name}-builddir")
          end
          if "#{autoreconf}" == true
            p "Running " + cmd
            unless "#{insource}" == true
              cmd = "autoreconf --force --install && mkdir #{name}-builddir && cd #{name}-builddir && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr"
            end
            if "#{insource}" == true
              cmd = "autoreconf --force --install && cd #{name} && ../configure --prefix=/opt/usr #{options} &&  make VERBOSE=1 -j 8 && make install prefix=/opt/usr"
            end
            system(cmd)
            system("rm -rfv  #{name}-builddir")
          end
        end
        $?.exitstatus
    when 'cmake'
      Dir.chdir(path) do
        p "running cmake #{options}"
        system("mkdir #{name}-builddir  && cd #{name}-builddir  && cmake #{options} ../ && make VERBOSE=1 -j 8 && make install")
      end
      $?.exitstatus
    when 'custom'
      unless "#{name}" == 'cpan'
        Dir.chdir("#{path}") do
          p "running #{options}"
          system("#{options}")
        end
      end
      if "#{name}" == 'cpan'
        p "running #{options}"
        system("#{options}")
      end
      $?.exitstatus
    when 'qmake'
      Dir.chdir("#{path}") do
        p "running qmake #{options}"
        system('echo $PATH')
        system("#{options}")
        system('make VERBOSE=1 -j 8 && make install')
      end
      $?.exitstatus
    when 'bootstrap'
      Dir.chdir(path) do
        p "running ./bootstrap #{options}"
        system("./bootstrap #{options}")
        system('make VERBOSE=1 -j 8 && make install')
      end
      $?.exitstatus
    else
    "You gave me #{buildsystem} -- I have no idea what to do with that."
    end
  end
end
