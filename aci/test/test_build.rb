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
      extra_command:  'qmake -set prefix "~/test_install"',
      prefix: '~/test_install'
    )
    assert_equal build.buildsystem, buildsystem
    assert_equal build.options, options
    assert_equal build.autoreconf, autoreconf
    assert_equal build.insource, insource
    assert_equal build.name, name
    assert_equal build.dir, Dir.pwd
    assert_equal build.file, 'qwt.pro'
    assert_equal build.extra_command, 'qmake -set prefix "~/test_install"'
    assert_equal build.prefix, '~/test_install'
  end

  def test_cmake
    Apt.install(['cmake'])
    system('git clone http://anongit.kde.org/extra-cmake-modules')
    name = 'extra-cmake-modules'
    buildsystem = 'cmake'
    options = '-DCMAKE_INSTALL_PREFIX:PATH=~/test_install/usr \
    -DKDE_INSTALL_SYSCONFDIR=~/test_install/etc \
    -DCMAKE_PREFIX_PATH=~/test_install/usr:/usr'
    insource = false
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      insource: insource,
      dir: Dir.pwd
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_insource
    system('git clone http://anongit.kde.org/extra-cmake-modules')
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
    assert_equal build.select_buildsystem, 0
    assert_equal File.directory?(
      File.join(dir, name, name + '-builddir')
    ), false
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_make
    Apt.install(['yasm'])
    system('wget ftp://ftp.videolan.org/pub/x264/snapshots/last_x264.tar.bz2; then \
	  mkdir x264 &&	tar xjvf last_x264.tar.bz2 -C x264 --strip-components 1')
    name = 'x264'
    buildsystem = 'make'
    options = '--enable-static --enable-shared --prefix=~/test_install/usr'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      dir: dir
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm('last_x264.tar.bz2')
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_autoreconf
    system('wget https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.26.tar.bz2; then \
    mkdir libgpg-error &&	tar xjvf libgpg-error-1.26.tar.bz2 -C libgpg-error --strip-components 1')
    name = 'libgpg-error'
    buildsystem = 'make'
    options = '--enable-static --enable-shared --prefix=' + Dir.home + '/test_install/usr'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      autoreconf: true,
      dir: dir
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm('libgpg-error-1.26.tar.bz2')
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_autogen
    Apt.install(['autoconf','automake','gettext'])
    system('wget https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.26.tar.bz2; \
    then mkdir libgpg-error &&	\
    tar xjvf libgpg-error-1.26.tar.bz2 -C libgpg-error --strip-components 1')
    name = 'libgpg-error'
    buildsystem = 'autogen'
    options = '--enable-static --enable-shared --prefix=' + Dir.home + '/test_install/usr'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      dir: dir
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm('libgpg-error-1.26.tar.bz2')
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_custom
    name = 'cpan'
    Dir.mkdir(name)
    buildsystem = 'custom'
    options = 'export PERL_MM_USE_DEFAULT=1 && cpan URI::Escape'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      dir: dir
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end

  def test_qmake
    Apt.install(['qmake'])
    system('sudo apt-get -y build-dep qwt-qt5-dev')
    system('svn export svn://svn.code.sf.net/p/qwt/code/branches/qwt-6.1')
    name = 'qwt-6.1'
    buildsystem = 'qmake'
    options = '"PREFIX = ~/usr"'
    dir = Dir.pwd
    build = Build.new(
      name: name,
      buildsystem: buildsystem,
      options: options,
      dir: dir,
      file: 'qwt.pro',
      extra_command:  'qmake -set prefix "~/test_install"',
      prefix: '~/test_install'
    )
    assert_equal build.select_buildsystem, 0
    FileUtils.rm_rf(File.join(Dir.pwd,  name))
    FileUtils.rm_rf(File.join(Dir.home, 'test_install'))
  end
end
