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

# Class for building source
class Build
  attr_accessor :buildsystem
  attr_accessor :name
  attr_accessor :options
  attr_accessor :insource
  attr_accessor :autoreconf
  attr_accessor :dir
  attr_accessor :file
  attr_accessor :pre_command
  attr_accessor :prefix
  attr_accessor :cmd
  def initialize(args = {})
    self.buildsystem = args[:buildsystem]
    self.options = args[:options]
    self.insource = args[:insource]
    self.autoreconf = args[:autoreconf]
    self.name = args[:name]
    self.dir = args[:dir]
    self.file = args[:file]
    self.pre_command = args[:pre_command]
    self.prefix = args[:prefix]
  end

  # Case block to select appriate scm type.
  def select_buildsystem
    case buildsystem
    when 'cmake'
      build_cmake_cmd
    when 'make'
      build_make_cmd
    when 'autogen'
      build_autogen_cmd
    when 'custom'
      build_custom_cmd
    when 'qmake'
      build_qmake_cmd
    when 'bootstrap'
      build_bootstrap_cmd
    else
      "You gave me #{buildsystem} -- I have no idea what to do with that."
    end
  end

  def build_cmake_cmd
    cmd =
      if insource == true
        "cmake #{options} && \
make VERBOSE=1 -j 8 && \
make install"
      else
        "mkdir builddir && \
cd builddir && \
cmake #{options} ../ && \
make VERBOSE=1 -j 8 && \
make install"
      end
    cmd
  end

  def run_build(cmd, pre_command = nil)
    Dir.chdir(File.join(dir, name))
    unless extra_command.nil?
      system(pre_command) if pre_command
    end
    system(cmd)
    $CHILD_STATUS.exitstatus
    Dir.chdir(dir)
  end

  def build_make_cmd
    cmd =
      if insource == false
        "mkdir builddir && \
cd builddir && \
../configure #{options} && \
make VERBOSE=1 -j 8 && \
make install"
      else
        "./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install"
      end
    cmd =
      if autoreconf == true
        'autoreconf --force --install && ' + cmd
      else
        cmd
      end
    cmd
  end

  def build_autogen_cmd
    cmd =
      if insource == false
        "./autogen.sh && \
mkdir builddir && \
cd builddir && \
../configure #{options} && \
make VERBOSE=1 -j 8 && \
make install"
      else
        "./autogen.sh &&
./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install"
      end
    cmd =
      if autoreconf == true
        'autoreconf --force --install && ' + cmd
      else
        cmd
      end
    cmd
  end

  def build_custom_cmd
    Dir.chdir(File.join(dir, name))
    system(options)
    Dir.chdir(dir)
    $CHILD_STATUS.exitstatus
  end

  def build_qmake_cmd
    cmd =
      if insource == false
        "mkdir builddir && cd builddir && \
        qmake #{options} ../#{file} && make VERBOSE=1 -j 8 && \
        INSTALL_ROOT=#{prefix} make install"
      else
        "qmake #{options} #{file}&& make VERBOSE=1 -j 8 \
        && INSTALL_ROOT=#{prefix} make install"
      end
    cmd
  end

  def build_bootstrap_cmd
    cmd =
      if insource == false
        "./bootstrap #{options} && \
         mkdir builddir && \
        cd builddir && \
       ../configure #{options} && \
       make VERBOSE=1 -j 8 && \
       make install"
      else
        "./bootstrap #{options} && \
        ./configure #{options} && \
        make VERBOSE=1 -j 8 && \
        make install"
      end
    cmd
  end
end
