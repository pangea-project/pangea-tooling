#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'date'
require 'fileutils'
require 'securerandom'

require_relative '../lib/ci/containment'
require_relative '../lib/nci'

# A helper to clean up dangling (too old) workspaces that weren't properly
# cleaned up by Jenkins itself.
module WorkspaceCleaner
  class << self
    # Paths must be run through fnmatch supporting functions so we can easily
    # grab all workspace variants. e.g. if the same server is shared for
    # multiple architectures we need to match /nci-armhf/ as well.
    DEFAULT_WORKSPACE_PATHS = ["#{Dir.home}/workspace",
                               "#{Dir.home}/nci*/workspace",
                               "#{Dir.home}/xci*/workspace"].freeze

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
      unless File.exist?(dir)
        warn "  Got error #{e} but still successfully removed directory."
        return
      end
      raise e unless e.class.name.start_with?('Errno::')

      warn "  Got error #{e}... trying to chown....."
      chown_r(dir)
      # Jenkins might still have a cleanup thread waiting for the dir, and if so
      # it may be gone after we solved the ownership problem.
      # If this is a cleanup dir, let it sit for now. If jenkins cleans it
      # up then that's cool, otherwise we'll get it in the next run.
      FileUtils.rm_r(dir, verbose: true) unless dir.include?('ws-cleanup')
    end

    def chown_r(dir)
      dist = ENV.fetch('DIST')
      user = CI::Containment.userns? ? 'root:root' : 'jenkins:jenkins'
      cmd = %w[/bin/chown -R] + [user, '/pwd']
      warn "  #{cmd.join(' ')}"
      c = CI::Containment.new(SecureRandom.hex,
                              image: CI::PangeaImage.new(:ubuntu, dist),
                              binds: ["#{dir}:/pwd"],
                              no_exit_handlers: true)
      c.run(Cmd: cmd)
      c.cleanup
    end

    def cleanup?(workspace)
      puts "Looking at #{workspace}"
      if workspace.include?('_ws-cleanup_')
        puts '  ws-cleanup => delete'
        return true
      end
       # Never delete current or future (series) mgmt workspaces.
      # Too dangerous as they are persistent.
      if workspace.include?('mgmt_#{NCI.current_series}' or 'mgmt_#{NCI.future_series}')
        puts '  mgmt => nodelete'
        return false
      end
      cleanup_age?(workspace)
    end

    def cleanup_age?(workspace)
      mtime = File.mtime(workspace)
      days_old = ((Time.now - mtime) / 60 / 60 / 24).to_i
      puts "  days old #{days_old}"
      days_old.positive?
    end
  end
end

# :nocov:
if $PROGRAM_NAME == __FILE__
  $stdout = STDERR # Force synced output
  WorkspaceCleaner.clean
end
# :nocov:
