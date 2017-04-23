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
require_relative '../libs/build'
require_relative '../libs/scm'
require_relative '../../ci-tooling/lib/apt'
require 'fileutils'
require 'test/unit'
require 'English'
require 'mocha/test_unit'

# Test various aspects of scm
class TestBuild < Test::Unit::TestCase

  def test_vars
    buildsystem = 'cmake'
    options =  '-DCMAKE_INSTALL_PREFIX:PATH=~/test_install/usr \
    -DKDE_INSTALL_SYSCONFDIR=~/test_install/etc \
    -DCMAKE_PREFIX_PATH=~/test_install/usr:/usr'
    autoreconf = false
    insource = false
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      autoreconf: autoreconf,
      insource: insource,
      dir: Dir.pwd,
      file: 'qwt.pro',
      pre_command:  'qmake -set prefix "~/test_install"',
      prefix: '~/test_install'
    )
    assert_equal build.buildsystem, buildsystem
    assert_equal build.options, options
    assert_equal build.autoreconf, autoreconf
    assert_equal build.insource, insource
    assert_equal build.name, name
    assert_equal build.dir, Dir.pwd
    assert_equal build.file, 'qwt.pro'
    assert_equal build.pre_command, 'qmake -set prefix "~/test_install"'
    assert_equal build.prefix, '~/test_install'
  end

  def test_cmake
    name = 'extra-cmake-modules'
    buildsystem = 'cmake'
    options = '-DCMAKE_INSTALL_PREFIX:PATH=~/test_install/usr \
      -DKDE_INSTALL_SYSCONFDIR=~/test_install/etc \
      -DCMAKE_PREFIX_PATH=~/test_install/usr:/usr'
    insource = true
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: insource,
      dir: dir
    )
    assert build.build_cmake_cmd
    assert_equal "cmake #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_cmake_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: false,
      dir: dir
    )
    assert_equal "mkdir builddir && \
cd builddir && \
cmake #{options} ../ && \
make VERBOSE=1 -j 8 && \
make install", build.build_cmake_cmd
    assert build.build_cmake_cmd
  end

  def test_make
    name = 'extra-cmake-modules'
    buildsystem = 'make'
    options = '--prefix=/opt/usr'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: false,
      dir: dir
    )
    assert_equal "mkdir builddir && \
cd builddir && \
../configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_make_cmd
    assert build.build_make_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: true,
      dir: dir
    )
    assert_equal "./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_make_cmd
    assert build.build_make_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: true,
      dir: dir,
      autoreconf: true
    )
    assert_equal "autoreconf --force --install && ./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_make_cmd
  end

  def test_autogen
    name = 'extra-cmake-modules'
    buildsystem = 'autogen'
    options = '--prefix=/opt/usr'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: false,
      dir: dir
    )
    assert_equal "./autogen.sh && \
mkdir builddir && \
cd builddir && \
../configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_autogen_cmd
    assert build.build_autogen_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: true,
      dir: dir
    )
    assert_equal "./autogen.sh && \
./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_autogen_cmd
    assert build.build_autogen_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: true,
      dir: dir,
      autoreconf: true
    )
    assert_equal "autoreconf --force --install && \
./autogen.sh && \
./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_autogen_cmd
  end

  def test_qmake
    name = 'extra-cmake-modules'
    buildsystem = 'qmake'
    options = '"PREFIX = ~/usr"'
    insource = true
    dir = Dir.pwd
    file =  'qwt.pro'
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: insource,
      dir: dir,
      file:file,
      pre_command: 'qmake -set prefix "~/test_install"'
    )
    assert build.build_qmake_cmd
    assert_equal "qmake #{options} #{file} && \
make VERBOSE=1 -j 8 && \
INSTALL_ROOT=#{prefix} make install", build.build_cmake_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: false,
      dir: dir,
      file: file,
      pre_command: 'qmake -set prefix "~/test_install"'
    )
    assert_equal "mkdir builddir && \
cd builddir && \
qmake #{options} ../#{file} && \
make VERBOSE=1 -j 8 && \
INSTALL_ROOT=#{prefix} make install", build.build_qmake_cmd
    assert build.build_qmake_cmd
  end

  def test_bootstrap
    name = 'extra-cmake-modules'
    buildsystem = 'bootstrap'
    options = '--prefix=/opt/usr'
    insource = true
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: insource,
      dir: dir,
      prefix: '~/test_install'
    )
    assert build.build_bootstrap_cmd
    assert_equal "./bootstrap #{options} && \
./configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_bootstrap_cmd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: false,
      dir: dir,
      prefix: '~/test_install'
    )
    assert_equal "./bootstrap #{options} && \
mkdir builddir && \
cd builddir && \
../configure #{options} && \
make VERBOSE=1 -j 8 && \
make install", build.build_bootstrap_cmd
    assert build.build_bootstrap_cmd
  end
end
