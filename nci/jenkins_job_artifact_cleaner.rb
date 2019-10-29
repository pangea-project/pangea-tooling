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

require_relative '../ci-tooling/lib/ci/pattern'

module NCI
  # Cleans up artifacts of lastSuccessfulBuild of jobs passed as array of
  # names.
  module JenkinsJobArtifactCleaner
    # Logic wrapper encapsulating the cleanup logic of a job.
    class Job
      # An entry in builds/permalinks identifying a common name for a
      # build (such as lastFailedBuild) and its respective build number (or -1)
      class Permalink
        attr_reader :id
        attr_reader :number

        def initialize(line)
          @id, @number = line.split(' ', 2)
          @number = @number.to_i
        end
      end

      # A permalinks file builds/permalinks representing the common names
      # to build numbers map.
      class Permalinks
        attr_reader :path
        attr_reader :links

        def initialize(path)
          @path = path
          @links = []

          File.open(path, 'r') do |f|
            f.each_line do |line|
              parse_line(line)
            end
          end
        end

        private

        def parse_line(line)
          line = line.strip
          return if line.empty? || !line.start_with?('last')
          raise "malformed line #{line} in #{path}" unless line.count(' ') == 1

          @links << Permalink.new(line)
        end
      end

      attr_reader :name
      attr_reader :build

      def initialize(name, build: 'lastSuccessfulBuild', verbose: true)
        @name = name
        @build = build.to_s # coerce, may be int
        # intentionally only controls our verbosity, not FU! AllJobs has no
        # use for us printing all builds we look at as it looks at all jobs
        # and 100 build seach, so it's a massive wall of noop information.
        @verbose = verbose
      end

      def self.jobs_dir
        # Don't cache, we mutate this during testing.
        File.join(ENV.fetch('JENKINS_HOME'), 'jobs')
      end

      def last_build_id
        # After errors jenkins sometimes implodes and fails to update the
        # symlinks, so we use a newer (and also a bit more efficient) peramlinks
        # file which contains the same information in a single file. Whatever
        # we find in there is the highest number, unless it is in fact not
        # a positive number in which case we still fall back to try our luck
        # with the symlinks.

        file = "#{builds_path}/permalinks"
        return last_build_id_by_symlink unless File.exist?(file)

        perma = Permalinks.new(file)
        numbers = perma.links.group_by(&:number).keys
        puts "  permanumbers #{numbers}"
        max = numbers.max
        return max if max.positive?

        last_build_id_by_symlink # fall back to legacy symlinks (needs readlink)
      end

      def last_build_id_by_symlink
        puts "Failed to get permalink for #{builds_path}, falling back to links"
        id = -1
        Dir.glob("#{builds_path}/last*").each do |link|
          begin
            new_id = File.basename(File.realpath(link)).to_i
            id = new_id if new_id > id
          rescue Errno::ENOENT # when the build/symlink is invalid
          end
        end
        id
      end

      def clean!
        marker = "#{path}/_artifact_cleaned"
        return unless File.exist?(path) # path doesn't exist, nothing to do
        return if File.exist?(marker) # this build was already cleaned

        puts "Cleaning #{name} in #{path}" if @verbose
        Dir.glob("#{path}/**/**") do |entry|
          next if File.directory?(entry)
          next unless BLACKLIST.any? { |x| x.match?(entry) }

          FileUtils.rm(entry, verbose: true)
        end

        FileUtils.touch(marker)
      end

      private

      def path
        File.join(builds_path, build, 'archive')
      end

      def builds_path
        File.join(jobs_dir, name, 'builds')
      end

      def jobs_dir
        self.class.jobs_dir
      end
    end

    BLACKLIST = [
      CI::FNMatchPattern.new('*.deb'),
      CI::FNMatchPattern.new('*.ddeb'),
      CI::FNMatchPattern.new('*.udeb'),
      CI::FNMatchPattern.new('*.orig.tar.*'),
      CI::FNMatchPattern.new('*.debian.tar.*'),
      CI::FNMatchPattern.new('*workspace.tar'), # Hand over from multijob to src
      CI::FNMatchPattern.new('*run_stamp'), # Generated by multijobs
      CI::FNMatchPattern.new('*fileParameters/*') # files got passed in
    ].freeze

    module_function

    def run(jobs)
      warn 'Cleaning up job artifacts to conserve disk space.'
      jobs.each do |job|
        Job.new(job).clean!
      end
      # Cleanup self as well.
      Job.new(ENV.fetch('JOB_BASE_NAME'),
              build: ENV.fetch('BUILD_NUMBER')).clean!
    end
  end
end

NCI::JenkinsJobArtifactCleaner.run(ARGV) if $PROGRAM_NAME == __FILE__
