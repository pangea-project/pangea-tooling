#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative 'jenkins_job_artifact_cleaner'

module NCI
  # Cleans up artifacts of lastSuccessfulBuild of jobs passed as array of
  # names.
  module JenkinsJobArtifactCleaner
    # Wrapper to clean ALL jobs and go back in their history. This is
    # a safety net to ensure we do not leak archive data
    class AllJobs
      def self.run
        Dir.foreach(Job.jobs_dir).each do |job_name|
          next if %w[. ..].include?(job_name)
          job = Job.new(job_name, verbose: false)
          build_id = job.last_build_id
          (back_count(build_id)..build_id).each do |id|
            Job.new(job_name, build: id, verbose: false).clean!
          end
        end
      end

      def self.back_count(id)
        ret = id - ENV.fetch('PANGEA_ARTIFACT_CLEAN_HISTORY', 100)
        ret.positive? ? ret : 1
      end
    end
  end
end

NCI::JenkinsJobArtifactCleaner::AllJobs.run if $PROGRAM_NAME == __FILE__
