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
require_relative '../libs/env'

describe 'set_env' do
  it 'Set environment variables' do
    expect(Env.set_env).to be(0), "Environment not set"
    expect(
      `echo $PATH`
      ).to be('/opt/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin')
  end
end

  # ENV['PATH']=
  # ENV['LD_LIBRARY_PATH']='/opt/usr/lib:/opt/usr/lib/x86_64-linux-gnu:/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib64:/usr/lib:/lib:/lib64'
  # ENV['CPLUS_INCLUDE_PATH']='/opt/usr:/opt/usr/include:/usr/include'
  # ENV['CFLAGS']="-g -O2 -fPIC"
  # ENV['CXXFLAGS']='-std=c++11'
  # ENV['PKG_CONFIG_PATH']='/opt/usr/lib/pkgconfig:/opt/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig'
  # ENV['ACLOCAL_PATH']='/opt/usr/share/aclocal:/usr/share/aclocal'
  # ENV['XDG_DATA_DIRS']='/opt/usr/share:/opt/share:/usr/local/share/:/usr/share:/share'
