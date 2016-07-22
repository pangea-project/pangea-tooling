#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#               2016 Scarlett Clark <sgclark@kde.org>
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

require_relative 'lib/appstreamer.rb'
require_relative 'lib/snap.rb'
require_relative 'lib/snapcraft.rb'

snap = Snap.new
# FIXME: cheeky
snap.name = File.read('snap.name')
snap.version = '16.04.1'
snap.stagedepends = ['plasma-integration']
p snap.stagedepends

desktopfile = "org.kde.#{snap.name}.desktop"
helpdesktopfile = 'org.kde.Help.desktop'

### appstream

appstreamer = AppStreamer.new(desktopfile)
appstreamer.expand(snap)
icon_url = appstreamer.icon_url
snap.apps = [Snap::App.new(snap.name)]

FileUtils.mkpath('snapcraft')
Dir.chdir('snapcraft')
File.write('snapcraft.yaml', snap.render)
FileUtils.cp("#{__dir__}/data/qt5-launch", '.')

Snapcraft.pull

desktop_url = "parts/#{snap.name}/install/usr/share/applications/#{desktopfile}"
help_desktop_url = "parts/#{snap.name}/install/usr/share/applications/#{helpdesktopfile}"

FileUtils.mkpath('setup/gui/')
FileUtils.cp(icon_url, 'setup/gui/icon') if icon_url
FileUtils.cp(desktop_url, "setup/gui/#{desktopfile}") if desktop_url
if File.exist?(help_desktop_url)
  FileUtils.cp(help_desktop_url, "setup/gui/#{helpdesktopfile}")
end

Snapcraft.run

Dir.glob('*.snap') do |f|
  system('zsyncmake', f) || raise
end
