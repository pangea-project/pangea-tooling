# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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
require 'gir_ffi'

# Appstream helper to extract data and expand another storage object
class AppStreamer
  def initialize(desktopfile)
    @desktopfile = desktopfile
    GirFFI.setup(:AppStream)
  end

  def database
    @db ||= AppStream::Database.new.tap(&:open)
  end

  def component
    @component ||= database.component_by_id(@desktopfile)
  end

  def expand(snap)
    if !component.nil?
      snap.summary = component.summary
      snap.description = component.description
    else
      snap.summary = 'No appstream summary, needs bug filed'
      snap.description = 'No appstream description, needs bug filed'
    end

    snap
  end

  def icon_url
    unless component.nil?
      component.icons.each do |icon|
        puts icon.kind
        puts icon.url
        next unless icon.kind == :cached
        return icon.url
      end
    end
    nil
  end
end
