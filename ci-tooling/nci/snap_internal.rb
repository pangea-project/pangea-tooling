#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'shellwords'

require_relative 'lib/appstreamer.rb'
require_relative 'lib/snap.rb'
require_relative 'lib/snapcraft.rb'

# Exclude all libraries, plugins, kcm-only packages, all of kdepim (useless
# without shared akonadi)
EXCLUDE_SNAPS = %w(
  eventviews gpgmepp grantleetheme incidenceeditor
  kaccounts-integration kcalcore kcalutils kcron kde-dev-scripts
  kdepim-addons kdepim-apps-libs kdgantt2 kholidays
  kidentitymanagement kimap kldap kmailtransport kmbox kmime kontactinterface
  kpimtextedit ktnef libgravatar libkdepim libkleo libkmahjongg
  libkomparediff2 libksieve mailcommon mailimporter messagelib
  pimcommon signon-kwallet-extension syndication akonadi akonadi-calendar
  akonadi-search calendarsupport kalarmcal kblog kcontacts kleopatra
  kdepim kdepim-runtime kdepimlibs baloo-widgets ffmpegthumbs dolphin-plugins
  akonadi-mime akonadi-notes analitza kamera kdeedu-data kdegraphics-thumbnailers
  kdenetwork-filesharing kdesdk-thumbnailers khelpcenter kio-extras kqtquickcharts
  kuser libkdcraw libkdegames libkeduvocdocument libkexiv2 libkface libkgeomap libkipi
  libksane
).freeze

snap = Snap.new(File.read('snap.name'), '16.04.1')
snap.stagedepends = ['plasma-integration']

# Packages we skip entirely
exit if EXCLUDE_SNAPS.include?(snap.name)

FileUtils.mkpath('snapcraft')
Dir.chdir('snapcraft')
# Temporary write a minimal file so we can pull our package
File.write('snapcraft.yaml', snap.render)
FileUtils.cp("#{__dir__}/data/qt5-launch", '.', verbose: true)

## pull & get necessary data bits

# This runs on the temporary incomplete data from above. Later snapcraft
# run will re-run parts that changed however, so even if stagedepends
# change after this they will end up in the stage properly.
Snapcraft.pull
root = "parts/#{snap.name}/install"

matches = Dir.glob("#{root}/usr/share/applications/*#{snap.name}*.desktop",
                   File::FNM_CASEFOLD)
if matches.size > 1
  matches.select! do |match|
    match.downcase.end_with?("org.kde.#{snap.name}.desktop".downcase)
  end
end
raise "can't find right desktop file #{matches}" if matches.size != 1
desktop_url = matches[0]
desktopfile = File.basename(desktop_url)

# Find exectuable
binname = File.read(desktop_url).split($/).select { |x| x.start_with?('Exec=') }
binname = Shellwords.split(binname[0].split('=', 2)[1])[0]
PATH = %w(/usr/sbin /usr/bin /sbin /bin /usr/games).freeze
binpath = nil
PATH.each do |path|
  b = "#{path}/#{binname}"
  next unless File.exist?("#{root}/#{b}")
  binpath = b
  puts "found binary #{b}"
  break
end
raise "can't find right binary #{binname}" unless binpath

## extract appstream data

appstreamer = AppStreamer.new(desktopfile)
appstreamer.expand(snap)
icon_url = appstreamer.icon_url
snap.apps = [Snap::App.new(snap.name, binary: binpath)]

puts snap.render
File.write('snapcraft.yaml', snap.render)

## copy data into place for snapcraft to find it

FileUtils.mkpath('setup/gui/')
FileUtils.cp(icon_url, 'setup/gui/icon') if icon_url
FileUtils.cp(desktop_url, "setup/gui/#{desktopfile}") if desktop_url

## finalize

Snapcraft.pull
Snapcraft.run

Dir.glob('*.snap') do |f|
  system('zsyncmake', f) || raise
end
