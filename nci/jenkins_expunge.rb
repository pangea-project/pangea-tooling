#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017-2019 Harald Sitter <sitter@kde.org>
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
module NCIJenkinsJobHistory
  def self.cleaning_paths_for(dir)
    [
      "#{dir}/archive",
      "#{dir}/injectedEnvVars.txt",
      "#{dir}/junitResult.xml",
      "#{dir}/log",
      "#{dir}/timestamper"
    ]
  end

  def self.mangle(jobdir)
    # Mangles "fairly" old builds to not include a log and test data anymore
    # The build temselves are still there for performance tracking and the
    # like.
    Jenkins::JobDir.each_ancient_build(jobdir,
                                       min_count: 256,
                                       max_age: 30 * 6) do |ancient_build|
      marker = "#{ancient_build}/_history_mangled"
      next if File.exist?(marker)
      next unless File.exist?(ancient_build) # just in case the dir disappeared
      next unless File.directory?(ancient_build) # don't trip over files

      # /dev/mapper/vg0-charlotte  1.3T  1.1T  168G  87% /
      FileUtils.rm_rf(cleaning_paths_for(ancient_build), verbose: true)

      FileUtils.touch(marker)
    end
  end

  def self.purge(jobdir)
    # Purges "super" old builds entirely so they don't even appear anymore.
    # NB: this intentionally has a lower min_count since the age is higher.
    #   Age restricts on top of min_count, we really do not care about builds
    #   that are older than 2 years regardless of how many builds there are!
    Jenkins::JobDir.each_ancient_build(jobdir,
                                       min_count: 64,
                                       max_age: 30 * 24) do |ancient_build|
      next unless File.directory?(ancient_build) # don't trip over files

      FileUtils.rm_rf(ancient_build, verbose: true)
    end
  end

  def self.clean
    jobsdir = "#{ENV.fetch('JENKINS_HOME')}/jobs"
    Dir.glob("#{jobsdir}/*").each do |jobdir|
      # this does interlaced looping so we have a good chance that the
      # directories are still in disk cache thus improving performance.
      name = File.basename(jobdir)
      puts "---- PURGE #{name} ----"
      purge(jobdir)
      puts "---- MANGLE #{name} ----"
      mangle(jobdir)
    end
  end
end

NCIJenkinsJobHistory.clean if $PROGRAM_NAME == __FILE__
