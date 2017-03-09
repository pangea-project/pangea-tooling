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

require_relative '../lib/jenkins/jobdir.rb'

# Archives all Jenkins job dirs it can find by moving it to the do-volume mount.
module NCI
  def self.jenkins_archive_builds(mnt_base = '')
    backupdir = "#{mnt_base}/mnt/volume-neon-jenkins/jobs.bak"
    FileUtils.mkpath(backupdir) unless Dir.exist?(backupdir)
    Dir.glob("#{Dir.home}/jobs/*").each do |jobdir|
      Jenkins::JobDir.each_ancient_build(jobdir,
                                         min_count: 16,
                                         max_age: 7 * 4 * 2) do |ancient_build|
        FileUtils.mv(ancient_build, backupdir, verbose: true)
      end
    end
  end
end

NCI.jenkins_archive_builds if __FILE__ == $PROGRAM_NAME
