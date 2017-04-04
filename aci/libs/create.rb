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
require_relative 'packages'
require_relative 'metadata'
require 'fileutils'
require 'open-uri'

# Call Appimagetool to do all the appimage creation bit
module Appimage
  def self.create_cmd(filename)
    cmd = './appimagetool-x86_64.AppImage -v -s -u "zsync|'
    cmd += filename
    cmd += '"  /app.Dir/ /appimages/'
    cmd += filename
    cmd
  end

  def self.create_zsync(filename, project)
    zsync = 'zsyncmake -u "https://s3-eu-central-1.amazonaws.com/ds9-apps/'
    zsync += project
    zsync += '-master-appimage/'
    zsync += filename
    zsync += '" -o /appimages/'
    zsync += filename
    zsync += '.zsync /appimages/'
    zsync += filename
    zsync
  end

  def self.get_tool(args = {})
    url = args[:url]
    file = args[:file]
    download = open(url)
    IO.copy_stream(download, file)
    FileUtils.chmod(0o755, file, verbose: true)
    $?.exitstatus
  end

  def self.retrieve_tools
    # get tools
    Dir.chdir('/')
    get_tool(
      url: 'https://github.com/probonopd/AppImageKit/releases/download/knowngood/appimagetool-x86_64.AppImage',
      file: 'appimagetool-x86_64.AppImage'
    )
  end

  def self.import_gpg
    # Import gpg key for appimagetool gpg signing.
    `gpg2 --import /root/.gnupg/appimage.key`
  end

  def self.create_appimage
    dated_cmd = create_cmd(Metadata::APPIMAGEFILENAME)
    dated_zsync = create_zsync(Metadata::APPIMAGEFILENAME, Metadata::PROJECT)
    latest = Metadata::PROJECT + '-latest-' + Metadata::ARCH + '.AppImage'
    latest_cmd = create_cmd(latest)
    latest_zsync = create_zsync(latest, Metadata::PROJECT)
    p dated_cmd
    system(dated_cmd.delete("\n"))
    p dated_zsync
    system(dated_zsync.delete("\n"))
    p latest_cmd
    system(latest_cmd.delete("\n"))
    p latest_zsync
    system(latest_zsync.delete("\n"))
  end
end
