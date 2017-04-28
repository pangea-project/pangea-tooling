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
require_relative '../libs/create'
require 'fileutils'
require 'test/unit'
require 'English'
require 'mocha/test_unit'

# Test various aspects of scm
class TestCreateAppimage < Test::Unit::TestCase

  @@project = 'extra-cmake-modules'
  @@filename = 'extra-cmake-modules-git04282017-x86_64.AppImage'

  def test_create_zsync
    zsync = 'zsyncmake -u "https://s3-eu-central-1.amazonaws.com/ds9-apps/'
    zsync += @@project
    zsync += '-master-appimage/'
    zsync += @@filename
    zsync += '" -o /appimages/'
    zsync += @@filename
    zsync += '.zsync /appimages/'
    zsync += @@filename
    assert_equal zsync, Appimage.create_zsync(@@filename, @@project)
  end

  def test_create_cmd
    cmd = './appimagetool-x86_64.AppImage -v -s -u "zsync|'
    cmd += @@filename
    cmd += '"  /app.Dir/ /appimages/'
    cmd += @@filename
    assert_equal cmd, Appimage.create_cmd(@@filename)
  end
end
