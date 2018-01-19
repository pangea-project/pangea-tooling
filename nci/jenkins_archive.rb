#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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
require 'pathname'

require_relative '../lib/jenkins/jobdir.rb'

# Archives all Jenkins job dirs it can find by moving it to the do-volume mount.
module NCI
  def self.relative_x_from_y(x, y)
    Pathname.new(x).relative_path_from(Pathname.new(y)).to_s
  end

  def self.jenkins_archive_builds_jobdir(jobdir, jobsdir, backupdir)
    Jenkins::JobDir.each_ancient_build(jobdir,
                                       min_count: 8,
                                       max_age: nil) do |ancient_build|
      next if File.symlink?(ancient_build) # skip already symlinked dirs
      relative_path = relative_x_from_y(ancient_build, jobsdir)
      target = "#{backupdir}/#{relative_path}"
      FileUtils.mkpath(File.dirname(target))
      FileUtils.mv(ancient_build, target, verbose: true)
      FileUtils.ln_s(target, ancient_build, verbose: true)
    end
  end

  def self.jenkins_archive_builds(mnt_base = '')
    backupdir = "#{mnt_base}/mnt/volume-neon-jenkins/jobs.bak"
    FileUtils.mkpath(backupdir)
    jobsdir = "#{Dir.home}/jobs"
    Dir.glob("#{jobsdir}/*").each do |jobdir|
      jenkins_archive_builds_jobdir(jobdir, jobsdir, backupdir)
    end
  end
end

NCI.jenkins_archive_builds if $PROGRAM_NAME == __FILE__
