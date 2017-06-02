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

require 'concurrent'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/jenkins'
require_relative 'job'

# Scores a job with regards to how many cores it should get.
module NCI
  module JenkinsBin
    # High level scoring system. Iterates all jobs and associates a
    # CPU core count with them.
    class JobScorer
      attr_reader :jobex
      attr_reader :config
      attr_reader :config_file

      CONFIG_FILE =
        File.absolute_path("#{__dir__}/../../data/nci/jobs-to-cores.json")

      def initialize(jobex: /.+_bin_amd64$/, config_file: CONFIG_FILE)
        @jobex = jobex
        @log = Logger.new(STDOUT)
        @config_file = config_file
        @config = JSON.parse(File.read(config_file))
        concurify!
      end

      def forget_missing_jobs!
        @config = config.select do |job|
          ret = all_jobs.include?(job)
          unless ret
            @log.warn "Dropping score of #{job}. It no longer exists in Jenkins"
          end
          ret
        end
        concurify!
      end

      def concurify!
        @config = Concurrent::Hash.new.merge(@config)
      end

      def all_jobs
        # This returns all jobs becuase to forget reliably we'll need to know
        # all jobs. Whether we filter here or at iteration makes no difference
        # though.
        @jobs ||= Jenkins.job.list_all.freeze
      end

      def score_job!(name)
        cores = Job.new(name).cores

        if !config.include?(name)
          @log.warn "Giving new job #{name} #{cores} cores"
        elsif config[name] != cores
          @log.warn "Changing job #{name} from #{config[name]} to #{cores}"
        end
        config[name] = cores
      end

      def run!
        forget_missing_jobs!

        pool = Concurrent::FixedThreadPool.new(4)
        promises = all_jobs.collect do |name|
          next unless jobex.match(name)
          Concurrent::Promise.execute(executor: pool) { score_job!(name) }
        end
        promises.compact.each(&:wait!)

        File.write(config_file, JSON.generate(config))
      end
    end
  end
end
