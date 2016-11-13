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
    # Database is now Pool
    @db ||= AppStream::Pool.new.tap(&:load)
  end

  def component
    # this returns at a gptr_array and I don't know how to deal with that.
    @component ||= database.get_components_by_id(@desktopfile)
  end

  # My temp solution is to use appstreamcli
  def hash
    output = []
    r, io = IO.pipe
    fork do
      system("appstreamcli get #{@desktopfile}", out: io, err: :out)
    end
    io.close
    r.each_line { |l| puts l; output << l.chomp }
    key_value = output.map {|item| item.split /:\s/ }
    hash ||= Hash[key_value]
    p hash
    hash
  end

  def expand(snap)
    # TO-DO AppStream API has changed and component now return a GPtrArray!!! I have banged my head against that and
    # just don't have the knowledge. Someone take if I do not get it.
    # Using a temp fix to green the jobs.
    # if !component.nil?
    #   snap.summary = component.summary
    #   p snap.summary
    #   snap.description = component.description
    # else
    #   snap.summary = 'No appstream summary, needs bug filed'
    #   snap.description = 'No appstream description, needs bug filed'
    # end

    if !component.nil?
      snap.summary = hash['Summary']
      snap.description = hash['Description']
    else
      snap.summary = 'No appstream summary, needs bug filed'
      snap.description = 'No appstream description, needs bug filed'
    end
    snap
  end

  def icon_url
    # unless component.nil?
    #   component.icons.each do |icon|
    #     puts icon.kind
    #     puts icon.url
    #     next unless icon.kind == :cached
    #     return icon.url
    #   end
    # end
    unless hash.nil?
      icons = hash['Icons']
      icons.each do |icon|
        puts icon.kind
        puts icon.url
        next unless icon.kind == :cached
        return icon.url
      end
    end
    nil
  end
end
