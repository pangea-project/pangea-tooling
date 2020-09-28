# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'deep_merge'
require 'yaml'

require_relative '../../lib/ci/pattern'

module NCI
  # NCI settings
  class Settings
    DEFAULT_FILES = [
      File.expand_path("#{__dir__}/../../data/settings/nci.yaml")
    ].freeze

    class << self
      def for_job
        new.for_job
      end

      def default_files
        @default_files ||= DEFAULT_FILES
      end

      attr_writer :default_files
    end

    def initialize(files = self.class.default_files)
      @default_paths = files
    end

    def for_job
      unless job?
        puts 'Could not determine job_name. ENV is missing JOB_NAME'
        return {}
      end
      job_patterns = CI::FNMatchPattern.filter(job, settings)
      job_patterns = CI::FNMatchPattern.sort_hash(job_patterns)
      return {} if job_patterns.empty?

      merge(job_patterns)
    end

    private

    def merge(job_patterns)
      folded = {}
      job_patterns.each do |patterns|
        patterns.each do |pattern|
          folded = folded.deep_merge(pattern)
        end
      end
      folded
    end

    def job?
      @job_exist ||= ENV.key?('JOB_NAME')
    end

    def job
      @job ||= ENV.fetch('JOB_NAME').strip
    end

    def settings
      @settings ||= load
    end

    def load
      hash = {}
      @default_paths.each do |path|
        hash.deep_merge!(YAML.load(File.read(path)))
      end
      hash = CI::FNMatchPattern.convert_hash(hash, recurse: false)
      hash
    end
  end
end
