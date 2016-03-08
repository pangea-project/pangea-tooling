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

module Jenkins
  # A Jenkins job directory handler. That is a directory in jobs/ and its
  # metadata.
  class JobDir
    STATE_SYMLINKS = %w(
      lastFailedBuild
      lastStableBuild
      lastSuccessfulBuild
      lastUnstableBuild
      lastUnsuccessfulBuild
    ).freeze

    def self.age(file)
      ((Time.now - File.mtime(file)) / 60 / 60 / 24).to_i
    end

    def self.recursive?(file)
      return false unless File.symlink?(file)
      abs_file = File.absolute_path(file)
      abs_file_dir = File.dirname(abs_file)
      link = File.readlink(abs_file)
      abs_link = File.absolute_path(link, abs_file_dir)
      abs_link == abs_file
    end

    def self.prune(dir, min_count: 6, max_age: 14)
      buildsdir = "#{dir}/builds"
      return unless File.exist?(buildsdir)
      content = Dir.glob("#{buildsdir}/*")

      locked = []
      content.reject! do |d|
        # Symlink but points to itself
        next true if recursive?(d)
        # Symlink is not a static one, keep these
        next false unless STATE_SYMLINKS.include?(File.basename(d))
        # Symlink, but points to invalid target
        next true unless File.symlink?(d) && File.exist?(d)
        locked << File.realpath(d)
      end

      # Filter now locked directories
      content.reject! { |d| locked.include?(File.realpath(d)) }

      content.sort_by! { |c| File.basename(c).to_i }
      content[0..-min_count].each do |d| # Always keep the last N builds.
        log = "#{d}/log"
        archive = "#{d}/archive"
        if File.exist?(log)
          FileUtils.rm(File.realpath(log)) if age(log) > max_age
        end
        if File.exist?(archive)
          FileUtils.rm_r(File.realpath(archive)) if age(archive) > max_age
        end
      end
    end
  end
end
