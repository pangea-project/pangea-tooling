#!/usr/bin/env ruby
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

require 'date'
require 'fileutils'

# A helper to clean up dangling (too old) workspaces that weren't properly
# cleaned up by Jenkins itself.
module WorkspaceCleaner
  class << self
    DEFAULT_WORKSPACE_PATHS = ["#{Dir.home}/workspace",
                               "#{Dir.home}/nci/workspace"].freeze

    def workspace_paths
      @workspace_paths ||= DEFAULT_WORKSPACE_PATHS.clone
    end

    attr_writer :workspace_paths

    def clean
      workspace_paths.each do |workspace_path|
        Dir.glob("#{workspace_path}/*") do |workspace|
          next unless File.directory?(workspace)
          next unless cleanup?(workspace)
          FileUtils.rm_rf(workspace, verbose: true)
        end
      end
    end

    private

    def cleanup?(workspace)
      return true if workspace.include?('_ws-cleanup_')
      days_old = ((Time.now - File.mtime(workspace)) / 60 / 60 / 24).to_i
      return true if days_old > 0
      false
    end
  end
end

# :nocov:
WorkspaceCleaner.clean if __FILE__ == $PROGRAM_NAME
# :nocov:
