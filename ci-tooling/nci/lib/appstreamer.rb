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
require 'rubygems/deprecate'

# Appstream helper to extract data and expand another storage object
class AppStreamer
  extend Gem::Deprecate

  def initialize(desktopfile)
    @desktopfile = desktopfile
    GirFFI.setup(:AppStream, '1.0')
  end

  def pool
    @pool ||= AppStream::Pool.new.tap(&:load)
  end

  def database
    pool
  end
  deprecate :database, :pool, 2016, 12

  def pick_single(components)
    case components.length
    when 0
      puts "Failed to resolve component for #{@desktopfile}"
      return nil
    when 1
      # good
    else
      raise "More than one component found #{components.map(&:id).join(', ')}"
    end
    components.index(0)
  end

  def component
    @component ||= begin
      cs = pool.components_by_id(@desktopfile)
      pick_single(cs)
    end
  end

  def expand(snap)
    if component
      snap.summary = component.summary
      snap.description = component.description
    else
      snap.summary = 'No appstream summary, needs bug filed'
      snap.description = 'No appstream description, needs bug filed'
    end

    snap
  end

  def icon_url
    return nil unless component
    component.icons.each do |icon|
      puts icon.kind
      puts icon.url
      next unless icon.kind == :cached
      return icon.url
    end
    nil
  end
end
