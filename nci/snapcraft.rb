#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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

require 'tty/command'

require_relative 'lib/setup_repo'
require_relative '../lib/apt'

require_relative 'snap/collapser'
require_relative 'snap/manifest_extender'
require_relative 'snap/snapcraft_snap_installer'

if $PROGRAM_NAME == __FILE__
  ENV['TERM'] = 'dumb' # make snpacraft not give garbage progress spam
  ENV['PYTHONUNBUFFERED'] = 'true' # make python also sync stdout
  STDOUT.sync = true
  # KDoctools is rubbish and lets meinproc resolve asset paths through
  #  QStandardPaths *AT BUILD TIME*.
  # TODO: can be dropped when build-snap transition is done (this completely
  #   moved to SDK wrappers; see also similar comment in collapser.rb)
  ENV['XDG_DATA_DIRS'] = "#{Dir.pwd}/stage/usr/local/share:" \
                         "#{Dir.pwd}/stage/usr/share:" \
                         '/usr/local/share:/usr/share'
  # Use our own remote parts file.
  ENV['SNAPCRAFT_PARTS_URI'] = 'https://metadata.neon.kde.org/snap/parts.yaml'
  # snapd is necessary for the snap CLI so we can download build-snaps.
  # docbook-xml and docbook-xsl are loaded by kdoctools through hardcoded paths.
  # FIXME libdrm-dev is pulled in because libqt5gui's cmake currently has its
  #   include path hard compiled and thus isn't picked up from the stage
  #   directory (which in turn already contains it because of the content
  #   snap dev tarball)
  #Apt.install(%w[docbook-xml docbook-xsl libdrm-dev snapd])

  # We somehow end up with a bogus ssl-dev in the images, drop it as otherwise
  # it may prevent snapcraft carrying out package installations (it doesn't
  # do problem resolution it seems).
  #Apt.purge('libssl1.0-dev')
  #NCI::Snap::BuildSnapCollapser.new('snapcraft.yaml').run do
    # switch to internal download URL
    non_managled_snap = File.read('snapcraft.yaml')
    mangled_snap = non_managled_snap.gsub(%r{download.kde.org/stable/}, 'download.kde.internal.neon.kde.org/stable/')
    File.write('snapcraft.yaml', mangled_snap)
    # Collapse first, extending also managles dpkg a bit, so we can't
    # expect packages to be in a sane state inside the extender.
    `sudo chown jenkins-slave /var/snap/lxd/common/lxd/unix.socket`
    `lxd init --auto`
    `snapcraft --version`
    `snapcraft clean --use-lxd || true`
    TTY::Command.new(uuid: false).run('snapcraft --use-lxd')
    File.write('snapcraft.yaml', non_managled_snap)
  #end
end
