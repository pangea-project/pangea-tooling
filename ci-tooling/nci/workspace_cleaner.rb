#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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
require 'securerandom'

require_relative '../../lib/ci/containment'

# A helper to clean up dangling (too old) workspaces that weren't properly
# cleaned up by Jenkins itself.
module WorkspaceCleaner
  class << self
    DEFAULT_WORKSPACE_PATHS = ["#{Dir.home}/workspace",
                               "#{Dir.home}/dci/workspace",
                               "#{Dir.home}/mci/workspace",
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
          rm_r(workspace)
        end
      end
    end

    private

    # Special rm_r, if a regular rm_r raises an errno, we'll attempt a chown
    # via containment and then try to remove again. This attempts to deal with
    # incomplete chowning by forcing it here. If the second rm_r still raises
    # something we'll let that go unhandled.
    def rm_r(dir)
      FileUtils.rm_r(dir, verbose: true)
    rescue SystemCallError => e
      if File.exist?(dir)
        warn "  Got error #{e} but still successfully removed directory."
        return
      end
      raise e unless e.class.name.start_with?('Errno::')
      warn "  Got error #{e} trying to chown."
      chown_r(dir)
      FileUtils.rm_r(dir, verbose: true)
    end

    def chown_r(dir)
      # TODO: drop: this is a transitional helper while the template has
      #   DIST not set.
      dist = ENV.fetch('DIST', 'xenial')
      c = CI::Containment.new(SecureRandom.hex,
                              image: CI::PangeaImage.new(:ubuntu, dist),
                              binds: ["#{dir}:/pwd"],
                              no_exit_handlers: true)
      c.run(Cmd: %w[/bin/chown -R jenkins:jenkins] + ['/pwd'])
      c.cleanup
    end

    def cleanup?(workspace)
      puts "Looking at #{workspace}"
      if workspace.include?('_ws-cleanup_')
        puts '  ws-cleanup => delete'
        return true
      end
      # Never delete mgmt workspaces. Too dangerous as they are
      # persistent.
      if workspace.include?('mgmt_')
        puts '  mgmt => nodelete'
        return false
      end
      cleanup_age?(workspace)
    end

    def cleanup_age?(workspace)
      mtime = File.mtime(workspace)
      days_old = ((Time.now - mtime) / 60 / 60 / 24).to_i
      puts "  days old #{days_old}"
      days_old > 0
    end
  end
end

# :nocov:
if $PROGRAM_NAME == __FILE__
  $stdout = STDERR # Force synced output
  WorkspaceCleaner.clean
end
# :nocov:
